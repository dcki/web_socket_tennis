class Competitor < ApplicationRecord
  validates :max_velocity, :min_velocity, presence: true, numericality: { greater_than: 0 }
  validate do
    if max_velocity && min_velocity
      if max_velocity < min_velocity
        errors.add(:max_velocity, 'must be greater than or equal to minimum velocity')
      end
    end
  end
end
