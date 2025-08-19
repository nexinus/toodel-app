class Team < ApplicationRecord
  belongs_to :creator, class_name: 'User'
  has_many :team_memberships, dependent: :destroy
  has_many :members, through: :team_memberships, source: :user
  has_many :matches, dependent: :destroy
  
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :max_members, numericality: { greater_than: 1, less_than_or_equal_to: 10 }
  validates :project_type, inclusion: { in: %w[academic startup research hackathon competition other] }
  validates :status, inclusion: { in: %w[forming active completed archived] }
  
  scope :active, -> { where(status: 'active') }
  scope :forming, -> { where(status: 'forming') }
  scope :by_university, ->(university) { where(university: university) }
  scope :by_project_type, ->(type) { where(project_type: type) }
  scope :needs_skills, ->(skills) { where("required_skills && ARRAY[?]::text[]", skills) }
  
  # Check if team is full
  def full?
    members.count >= max_members
  end
  
  # Check if user is a member
  def member?(user)
    members.include?(user)
  end
  
  # Check if user is admin or creator
  def admin?(user)
    return true if user == creator
    team_memberships.find_by(user: user)&.role == 'admin'
  end
  
  # Add member to team
  def add_member(user, role: 'member')
    return false if full?
    return false if member?(user)
    
    team_memberships.create!(
      user: user,
      role: role,
      joined_at: Time.current
    )
  end
  
  # Remove member from team
  def remove_member(user)
    membership = team_memberships.find_by(user: user)
    return false unless membership
    
    membership.update(status: 'removed')
    true
  end
  
  # Get available skill slots
  def skill_gaps
    required_skills - members.joins(:skills).pluck(:skills).flatten.uniq
  end
  
  # Check if team has all required skills
  def skills_complete?
    skill_gaps.empty?
  end
end

