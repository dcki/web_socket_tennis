class GameSimulationWorker
  include Sidekiq::Worker

  def perform(player_ids)
    player1 = User.find(player_ids[0])
    player2 = User.find(player_ids[1])

    redis = Redis.new

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

          case channel
          when redis_pubsub_channel(player1)
            @player1_paddle_state = paddle_state if valid_paddle_state?(paddle_state)
          when redis_pubsub_channel(player2)
            @player2_paddle_state = paddle_state if valid_paddle_state?(paddle_state)
          end

          # This shouldn't be here. Maybe put it in another thread.
          GameChannel.broadcast_to(player1, event: 'update', paddle1: @player1_paddle_state, paddle2: @player2_paddle_state)
          GameChannel.broadcast_to(player2, event: 'update', paddle1: @player1_paddle_state, paddle2: @player2_paddle_state)
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

    # Seems like we never get here. I guess the subscribe block above holds onto execution.

    sleep(0.1) until @player1_paddle_state && @player2_paddle_state

    100.times do
      GameChannel.broadcast_to(player1, event: 'update', paddle1: @player1_paddle_state, paddle2: @player2_paddle_state)
      GameChannel.broadcast_to(player2, event: 'update', paddle1: @player1_paddle_state, paddle2: @player2_paddle_state)
      sleep 0.1
    end

    GameChannel.broadcast_to(player1, event: 'end')
    GameChannel.broadcast_to(player2, event: 'end')
  end

  private

  def redis_pubsub_channel(user)
    "game:player#{user.id}"
  end

  def valid_paddle_state?(message)
    %w[up down stop].include?(message)
  end
end
