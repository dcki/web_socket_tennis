class GameChannel < ApplicationCable::Channel
  def subscribed
  end

  def unsubscribed
  end

  # Is this covered by unsubscribed?
  def broken_connection
  end

  def player_action
  end
end
