class Game < ApplicationRecord
  has_many :game_memberships, dependent: :destroy
  has_many :users, through: :game_memberships

  scope :incomplete, -> { where(completed_at: nil) }
end
