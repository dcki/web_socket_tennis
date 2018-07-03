class User < ApplicationRecord
  has_many :competitors, dependent: :destroy
  has_many :game_memberships, dependent: :destroy
  has_many :games, through: :game_memberships

  validates :name, length: { in: 1..100 }

  def self.find_by_session(cookies)
    User.find_by_id(cookies.encrypted[:user_id])
  end

  def self.set_encrypted_session_id(cookies, new_id)
    cookies.encrypted[:user_id] = new_id
  end
end
