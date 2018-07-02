class GameChannel < ApplicationCable::Channel

  # CAUTION
  #
  # I'm pretty sure clients can perform actions even if they ultimately are rejected.
  # They may even be able to perform actions after rejection; I'm less sure.
  #
  # Consequently, DO NOT USE PARAMS (for example params[:game_id]) for anything other
  # than authorization. Any reads or writes done in any action should grant access
  # only based on instance variables created in the `subscribed` method.
  #
  # Or, really, make sure that any params used have been verified to be accessable by
  # the current user.
  #
  # (The params method contains scoping information provided when the client attempts
  # to subscribe to a channel.)
  #
  # (All that said, this is just a silly game. Failure to prevent unauthorized access
  # to another player's game would not be that bad. But if every example Action Cable
  # app does authorization wrong, then someone might continue that pattern in an app
  # where authorization does matter.)

  def subscribed
    @game = Game.joins(:users).
      where(id: params[:game_id], users: { id: current_user.id }).first
    if @game
      stream_for [current_user, @game]
    else
      # TODO test
      reject
    end
  end

  def unsubscribed
    _stop
  end

  def stop
    _stop
  end

  def paddle(data)
    publish_to_worker(
      paddle_state: data['paddle_state'],
    )
  end

  private

  def _stop
    publish_to_worker(
      command: 'die',
    )
    # In case the job no longer exists and will never end the game.
    @game.update_attribute(:completed_at, Time.now)
  end

  def publish_to_worker(data)
    redis.publish(
      "to_game_worker:#{@game.id}:#{current_user.id}",
      {
        time_published: Time.now.iso8601(6),
      }.merge(data).to_json
    )
  end

  def redis
    @redis ||= Redis.new
  end
end
