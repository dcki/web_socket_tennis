class GameMembership < ApplicationRecord
  belongs_to :user
  belongs_to :game

  validates :user_id, :game_id, presence: true

  scope :incomplete, -> { joins(:game).merge(Game.incomplete) }
end
