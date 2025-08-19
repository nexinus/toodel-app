class TeamMembership < ApplicationRecord
  belongs_to :user
  belongs_to :team
  
  validates :role, inclusion: { in: %w[creator admin member] }
  validates :status, inclusion: { in: %w[active inactive removed] }
  validates :user_id, uniqueness: { scope: :team_id }
  
  scope :active, -> { where(status: 'active') }
  scope :admins, -> { where(role: ['creator', 'admin']) }
  
  before_create :set_joined_at
  
  private
  
  def set_joined_at
    self.joined_at = Time.current
  end
end

