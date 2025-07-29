class Match < ApplicationRecord
  belongs_to :user
  belongs_to :target, class_name: 'User'

  validates :kind, inclusion: { in: %w[pass connect] }
  # Optionally enforce uniqueness so you don’t swipe the same user twice:
  validates :target_id, uniqueness: { scope: :user_id }
end
