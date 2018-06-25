class MatchMakingChannel < ApplicationCable::Channel
  def subscribed
    # reject if current_user_unauthorized
  end

  def unsubscribed
    # Delete any outstanding matchmaking records
  end

  def create_game
    return if Competitor.find_by_user_id(current_user.id)
    max_velocity = 1
    min_velocity = 1
    Competitor.transaction do
      competitor = Competitor.lock('FOR UPDATE SKIP LOCKED').
        # I did this when I was tired. Is it right?
        where('max_velocity >= ?', min_velocity).
        where('min_velocity <= ?',  max_velocity).
        first
      if competitor
        GameSimulationWorker.perform_async([competitor.user_id, current_user.id])
        competitor.destroy
      else
        Competitor.create!(user_id: current_user.id, max_velocity: max_velocity, min_velocity: min_velocity)
      end
    end
  end
end
