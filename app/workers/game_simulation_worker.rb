class GameSimulationWorker
  include Sidekiq::Worker

  def perform(game_id, speed)
    @game = Game.incomplete.where(id: game_id).first

    return unless @game && speed.is_a?(Numeric)

    record_start_time

    player1, player2 = @game.users

    game_loop_redis = Redis.new
    client_redis = Redis.new

    # Autoload before referencing in thread because that causes some kind of deadlock
    # and the thread never wakes up again if it tries to autoload this.
    GameChannel

    # TODO Get thread from a pool.
    thr = Thread.new do

      until @player1_paddle_state && @player2_paddle_state
        if game_start_timeout
          @quit = true
          break
        end
        sleep(0.1)
      end

      level = {
        width: 400.0,
        height: 200.0,
      }
      ball_dimensions = {
        width: 10.0,
        height: 10.0,
      }
      paddle_dimensions = {
        width: 20.0,
        height: 40.0,
      }
      paddle1 = {
        x: 0.0,
        y: (level[:height] - paddle_dimensions[:height]) / 2.0,
      }
      paddle2 = {
        x: level[:width] - paddle_dimensions[:width],
        y: (level[:height] - paddle_dimensions[:height]) / 2.0,
      }
      ball = {
        x: 0.0,
        y: 0.0,
      }

      game_object_positions = {
        paddle1: paddle1,
        paddle2: paddle2,
        ball: ball,
      }

      message_without_dimensions = {
        game_object_positions: game_object_positions,
      }
      message_with_dimensions = {
        game_object_positions: game_object_positions,
        game_objects: {
          level: level,
          ball: ball_dimensions,
          paddle: paddle_dimensions,
        },
      }

      speed = speed.to_f
      dx = speed
      dy = speed

      loop do
        case @player1_paddle_state
        when 'up'
          paddle1[:y] -= speed
          paddle1[:y] = [paddle1[:y], 0.0].max
        when 'down'
          paddle1[:y] += speed
          paddle1[:y] = [paddle1[:y], level[:height] - paddle_dimensions[:height]].min
        end

        case @player2_paddle_state
        when 'up'
          paddle2[:y] -= speed
          paddle2[:y] = [paddle2[:y], 0.0].max
        when 'down'
          paddle2[:y] += speed
          paddle2[:y] = [paddle2[:y], level[:height] - paddle_dimensions[:height]].min
        end

        if collide?(ball, ball_dimensions, paddle1, paddle_dimensions)
          dy = corner_bounce(dy, speed, paddle1, paddle_dimensions, ball, ball_dimensions)

          dx = speed
        end

        if collide?(ball, ball_dimensions, paddle2, paddle_dimensions)
          dy = corner_bounce(dy, speed, paddle2, paddle_dimensions, ball, ball_dimensions)

          dx = -speed
        end

        if ball[:y] <= 0.0
          dy = dy.abs
        end

        if ball[:y] + ball_dimensions[:width] >= level[:height]
          dy = -(dy.abs)
        end

        ball[:x] += dx
        ball[:y] += dy

        if (
            ball[:x] < 0.0 ||
            ball[:x] > level[:width] - ball_dimensions[:width] ||
            at_least_one_player_out_of_contact_for(5.seconds) ||
            @quit
        )
          # Tell other thread to unsubscribe so it can quit.
          game_loop_redis.publish(
            redis_pubsub_channel_for_worker,
            {
              command: 'die',
              # Make sure message is not ignored for being too old.
              time_published: 100.days.from_now.iso8601(6),
            }.to_json
          )
          break
          # Go to CLEAN UP below.
        end

        # Save bandwidth
        if rand < 0.1
          message = message_with_dimensions
        else
          message = message_without_dimensions
        end

        GameChannel.broadcast_to([player1, @game], message)
        GameChannel.broadcast_to([player2, @game], message)

        sleep 0.02
      end
    end

    begin
      client_redis.subscribe(
        redis_pubsub_channel(player1),
        redis_pubsub_channel(player2),
        redis_pubsub_channel_for_worker
      ) do |on|
        on.subscribe do |channel, subscriptions|
          #puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end

        on.message do |channel, message|
          message = MultiJson.load(message, symbolize_keys: true)

          time_published = Time.parse(message[:time_published])

          # Ignore old messages.
          next if time_published < (Time.now - 0.5.seconds)

          if message[:command] == 'die'
            @quit = true
            client_redis.unsubscribe
            next
            # Go to CLEAN UP below.
          end

          paddle_state = message[:paddle_state]

          case channel
          when redis_pubsub_channel(player1)
            @player1_updated_at = Time.now
            @player1_paddle_state = paddle_state if valid_paddle_state?(paddle_state)
          when redis_pubsub_channel(player2)
            @player2_updated_at = Time.now
            @player2_paddle_state = paddle_state if valid_paddle_state?(paddle_state)
          end
        end

        on.unsubscribe do |channel, subscriptions|
          #puts "Unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
        end
      end
    rescue Redis::BaseConnectionError => error
      #puts "#{error}, retrying in 1s"
      sleep 0.1
      retry
    end

    # CLEAN UP

    thr.join

    @game.update_attribute(:completed_at, Time.now)

    GameChannel.broadcast_to([player1, @game], game_over: true)
    GameChannel.broadcast_to([player2, @game], game_over: true)
  end

  private

  def redis_pubsub_channel(user)
    "to_game_worker:#{@game.id}:#{user.id}"
  end

  def redis_pubsub_channel_for_worker
    "to_game_worker:#{@game.id}:from_worker"
  end

  def valid_paddle_state?(message)
    %w[up down stop].include?(message)
  end

  def collide?(a, a_dim, b, b_dim)
    if a[:x] <= b[:x] + b_dim[:width] &&
        a[:x] + a_dim[:width] >= b[:x] &&
        a[:y] <= b[:y] + b_dim[:height] &&
        a[:y] + a_dim[:height] >= b[:y]
      true
    end
  end

  # This is intentionally changing not just the direction but also the speed of
  # the ball (because it doesn't decrease dx when it increases dy). It doesn't
  # make sense physically, but this is a game, and I think this behavior will
  # be more fun.
  #
  # We could make the current movement of the paddle affect speed instead or in
  # addition.
  def corner_bounce(dy, speed, paddle, paddle_dimensions, ball, ball_dimensions)
    dy + speed * magnitude(paddle, paddle_dimensions, ball, ball_dimensions)
  end

  def magnitude(paddle, paddle_dimensions, ball, ball_dimensions)
    (
      (ball[:y] + ball_dimensions[:height] / 2.0) -
      (paddle[:y] + paddle_dimensions[:height] / 2.0)
    ) / (paddle_dimensions[:height] / 2.0)
  end

  def at_least_one_player_out_of_contact_for(interval)
    [@player1_updated_at, @player2_updated_at].min < Time.now - interval
  end

  def record_start_time
    @start_time ||= Time.now
  end

  def game_start_timeout
    @start_time < 10.seconds.ago
  end
end
