class GameSimulationWorker
  include Sidekiq::Worker

  def perform(game_id)
    game = Game.find(game_id)

    player1, player2 = game.users

    redis = Redis.new

    # Autoload before referencing in thread because that causes some kind of deadlock
    # and the thread never wakes up again if it tries to autoload this.
    GameChannel

    # TODO Get thread from a pool.
    thr = Thread.new do

      sleep(0.1) until @player1_paddle_state && @player2_paddle_state

      @level = {
        width: 400,
        height: 200,
      }
      @ball_dimensions = {
        width: 20,
      }
      @paddle1 = {
        x: 0,
        y: 0,
      }
      @paddle2 = {
        x: @level[:width] - @ball_dimensions[:width],
        y: 0,
      }
      @ball = {
        x: 0,
        y: 0,
      }


      game_object_positions = {
        paddle1: @paddle1,
        paddle2: @paddle2,
        ball: @ball,
      }

      speed = 1
      dx = speed
      dy = speed

      until @quit do
        case @player1_paddle_state
        when 'up'
          @paddle1[:y] -= 2
        when 'down'
          @paddle1[:y] += 2
        end

        case @player2_paddle_state
        when 'up'
          @paddle2[:y] -= 2
        when 'down'
          @paddle2[:y] += 2
        end

        if collide?(@ball.merge(width: 20, height: 20), @paddle1.merge(width: 20, height: 40))
          dx = speed
        end

        if collide?(@ball.merge(width: 20, height: 20), @paddle2.merge(width: 20, height: 40))
          dx = -speed
        end

        if @ball[:y] <= 0
          dy = speed
        end

        if @ball[:y] + @ball_dimensions[:width] >= @level[:height]
          dy = -speed
        end

        @ball[:x] += dx
        @ball[:y] += dy

        if @ball[:x] < 0 - @ball_dimensions[:width] || @ball[:x] > @level[:width]
          @quit = true
          next
        end

        # TODO Don't produce so many objects that have to be garbage collected.
        message = {
          game_object_positions: game_object_positions,
        }

        if rand < 0.1
          message.merge!(
            game_objects: {
              level: @level,
              ball: @ball_dimensions,
            },
          )
        end

        GameChannel.broadcast_to(player1, message)
        GameChannel.broadcast_to(player2, message)
        sleep 0.01
      end
    end

    begin
      redis.subscribe(redis_pubsub_channel(player1), redis_pubsub_channel(player2)) do |on|
        on.subscribe do |channel, subscriptions|
          #puts "Subscribed to ##{channel} (#{subscriptions} subscriptions)"
        end

        on.message do |channel, message|
          #puts "##{channel}: #{message}"
          #redis.unsubscribe if message == "exit"

          message = MultiJson.load(message, symbolize_keys: true)

          paddle_state = message[:paddle_state]
          time_published = Time.parse(message[:time_published])

          # Ignore old messages.
          next if time_published < (Time.now - 0.5.seconds)

          if message[:command] == 'die' || @quit
            redis.unsubscribe
            @quit = true
            next
          end

          case channel
          when redis_pubsub_channel(player1)
            @player1_paddle_state = paddle_state if valid_paddle_state?(paddle_state)
          when redis_pubsub_channel(player2)
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

    thr.join

    game.destroy

    GameChannel.broadcast_to(player1, game_over: true)
    GameChannel.broadcast_to(player2, game_over: true)
  end

  private

  def redis_pubsub_channel(user)
    "game:player#{user.id}"
  end

  def valid_paddle_state?(message)
    %w[up down stop].include?(message)
  end

  def collide?(a, b)
    if a[:x] <= b[:x] + b[:width] &&
        a[:x] + a[:width] >= b[:x] &&
        a[:y] <= b[:y] + b[:height] &&
        a[:y] + a[:height] >= b[:y]
      true
    end
  end
end
