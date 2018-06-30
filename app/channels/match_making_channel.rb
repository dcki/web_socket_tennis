class MatchMakingChannel < ApplicationCable::Channel
  def subscribed
    stream_for current_user
    # reject if current_user_unauthorized
  end

  def unsubscribed
    # Delete any outstanding matchmaking records
  end

  # TODO this seems fragile, like dropped connections or page refreshes may lead to lingering inactive Competitor records.
  # Or what if the client performs join_game after being pulled into an active GameSimulatorWorker?
  def join_game(data)
    return if GameMembership.incomplete.find_by_user_id(current_user.id)
    min_velocity = data['min_velocity'].to_i
    max_velocity = data['max_velocity'].to_i
    if min_velocity > max_velocity
      self.class.broadcast_to current_user, error: 'min greater than max'
    end
    Competitor.transaction do
      # TODO if 2 requests try to lock a competitor for the same user and no competitor exists, it's possible they will both create a competitor for the user. Possible solution: move to data model where competitor info is stored on user instead, or where every user always has one competitor and it gets updated.
      competitor = Competitor.lock('FOR UPDATE SKIP LOCKED').
        # I did this when I was tired. Is it right?
        where('max_velocity >= ?', min_velocity).
        where('min_velocity <= ?',  max_velocity).
        where('user_id != ?', current_user.id).
        first
      if competitor
        competitor.destroy
        game = Game.create!
        game.users << [competitor.user, current_user]
        GameSimulationWorker.perform_async(game.id, [competitor.max_velocity, max_velocity].min)
      else
        Competitor.create!(user_id: current_user.id, min_velocity: min_velocity, max_velocity: max_velocity)
      end
    end
  end
end
