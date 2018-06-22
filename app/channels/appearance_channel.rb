class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "appearance:all"
    AppearanceChannel.broadcast_to("all", event: 'subscribed')
    #current_user.appear
  end

  def unsubscribed
    AppearanceChannel.broadcast_to("all", event: 'unsubscribed')
    #current_user.disappear
  end

  def appear(data)
    #current_user.appear(on: data['appearing_on'])
    AppearanceChannel.broadcast_to("all", event: 'appear', appearing_on: data['appearing_on'])
  end

  def away
    #current_user.away
    AppearanceChannel.broadcast_to("all", event: 'away')
  end

  def return_from_away
    #current_user.return_from_away
    AppearanceChannel.broadcast_to("all", event: 'return_from_away')
  end
end
