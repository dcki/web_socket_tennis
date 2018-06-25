class GameChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
    # reject if current_user_unauthorized
    @redis = Redis.new
  end

  def unsubscribed
  end

  # Is this covered by unsubscribed?
  def broken_connection
  end

  def paddle(data)
    @redis.publish(
      "game:player#{current_user.id}",
      {
        paddle_state: data['paddle_state'],
        time_published: Time.now.iso8601(6),
      }.to_json
    )
  end
end
