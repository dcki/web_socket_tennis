class GameChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
    # reject if current_user_unauthorized
    @redis = Redis.new
  end

  def unsubscribed
    _stop
  end

  # Is this covered by unsubscribed?
  def broken_connection
  end

  # TODO Sometimes after a game there are a bunch of errors related to this action.
  def paddle(data)
    @redis.publish(
      "game:player#{current_user.id}",
      game_message(
        paddle_state: data['paddle_state'],
      )
    )
  end

  def stop
    _stop
  end

  private

  def _stop
    # TODO I wonder if this is reliable. Maybe there should be a recurring job (like cron) to publish to workers that they should end the current job if no client messages have been received recently.
    @redis.publish(
      "game:player#{current_user.id}",
      game_message(
        command: 'die',
      )
    )
  end

  def game_message(message)
    {
      time_published: Time.now.iso8601(6),
    }.merge(message).to_json
  end
end
