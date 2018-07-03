# TODO Communicating between client and server with Action Cable seems to generally
# be more complex than using regular Rails controllers. The work done by this channel
# should probably all be done in a controller instead.
class MatchMakingChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
    # reject if current_user_unauthorized
  end

  def unsubscribed
    current_user.competitors.destroy_all
  end

  def join_game(data)
    # TODO notify client about result of join_game call so client can reliably communicate
    # current state to user.
    game_membership = GameMembership.incomplete.find_by_user_id(current_user.id)
    if game_membership
      MatchMakingChannel.broadcast_to(current_user, new_game_id: game_membership.game_id)
      return
    end
    game = nil
    competitor = nil
    min_velocity = data['min_velocity'].to_i
    max_velocity = data['max_velocity'].to_i
    if min_velocity > max_velocity
      MatchMakingChannel.broadcast_to current_user, error: 'min greater than max'
    end
    Competitor.transaction do
      # TODO if 2 requests try to lock a competitor for the same user and no competitor
      # exists, it's possible they will both create a competitor for the user. Possible
      # solution: move to data model where competitor info is stored on user instead, or
      # where every user always has one competitor and it gets updated. Or add unique
      # index on competitors.user_id.
      competitor = Competitor.lock('FOR UPDATE SKIP LOCKED').
        where('max_velocity >= ?', min_velocity).
        where('min_velocity <= ?',  max_velocity).
        where('user_id != ?', current_user.id).
        first
      if competitor
        competitor.destroy
        game = Game.create!
        game.users << [competitor.user, current_user]
      else
        Competitor.create!(
          user_id: current_user.id,
          min_velocity: min_velocity,
          max_velocity: max_velocity
        )
      end
    end

    if game
      MatchMakingChannel.broadcast_to(game.users[0], new_game_id: game.id)
      MatchMakingChannel.broadcast_to(game.users[1], new_game_id: game.id)

      GameSimulationWorker.perform_async(
        game.id,
        [competitor.max_velocity, max_velocity].min
      )
    end
  end
end
