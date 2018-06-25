class MatchMakingChannel < ApplicationCable::Channel
  def subscribed
    #stream_from "appearance:all"
    #stream_for
    # reject if current_user...
  end
end
