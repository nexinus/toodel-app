class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Relationships
  has_many :matches, dependent: :destroy
  has_many :swiped_users, through: :matches, source: :target
  has_many :team_memberships, dependent: :destroy
  has_many :teams, through: :team_memberships
  has_many :created_teams, class_name: 'Team', foreign_key: 'creator_id'
  has_many :inverse_matches,
           class_name: "Match",
           foreign_key: "target_id",
           dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :university, presence: true
  validates :degree_program, presence: true
  validates :year_of_study, presence: true, 
            numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validates :preferred_project_types, presence: true
  validates :availability, presence: true
  
  # Scopes
  scope :looking_for_teammates, -> { where(looking_for_teammates: true) }
  scope :by_university, ->(university) { where(university: university) }
  scope :by_degree_program, ->(program) { where(degree_program: program) }
  scope :by_year, ->(year) { where(year_of_study: year) }
  scope :with_skills, ->(skills) { where("skills && ARRAY[?]::text[]", skills) }
  scope :by_project_type, ->(type) { where("preferred_project_types && ARRAY[?]::text[]", type) }
  
  # Instance methods
  def display_name
    hide_last_name ? name.split(' ').first : name
  end
  
  def full_profile?
    university.present? && degree_program.present? && 
    year_of_study.present? && skills.present? && 
    availability.present? && preferred_project_types.present?
  end
  
  def skill_tags
    skills&.split(',')&.map(&:strip) || []
  end
  
  def project_type_tags
    preferred_project_types || []
  end
  
  def communication_tags
    communication_preferences || []
  end
  
  def available_for_projects?
    looking_for_teammates && full_profile?
  end
  
  def team_member?
    team_memberships.active.exists?
  end
  
  def active_teams
    teams.joins(:team_memberships).where(team_memberships: { status: 'active' })
  end
  
  def pending_invitations
    matches.where(status: 'pending', action_type: 'invite')
  end
  
  def accepted_invitations
    matches.where(status: 'accepted', action_type: 'invite')
  end
  
  def mutual_matches
    # Find matches where both users have accepted each other's invitations
    # This is a mutual match: user A invited user B, and user B also invited user A
    # Both invitations must be accepted for it to be a mutual match
    mutual_matches = []
    
    # Get all accepted invitations sent by this user
    my_accepted_invitations = matches.where(action_type: 'invite', status: 'accepted')
    
    my_accepted_invitations.each do |my_invitation|
      # Check if the target user also sent an accepted invitation to this user
      their_invitation = Match.find_by(
        user: my_invitation.target,
        target: self,
        action_type: 'invite',
        status: 'accepted'
      )
      
      if their_invitation
        mutual_matches << my_invitation
      end
    end
    
    mutual_matches
  end
  
  # Compatibility scoring for matching algorithm
  def compatibility_score_with(other_user)
    score = 0
    
    # University proximity (same university = higher score)
    score += 50 if university == other_user.university
    
    # Year of study compatibility (similar years = higher score)
    # Only calculate year difference if both users have year_of_study values
    if year_of_study.present? && other_user.year_of_study.present?
      year_diff = (year_of_study - other_user.year_of_study).abs
      score += (10 - year_diff) * 2 if year_diff <= 5
    end
    
    # Skills overlap
    common_skills = skill_tags & other_user.skill_tags
    score += common_skills.length * 10
    
    # Project type preferences overlap
    common_projects = project_type_tags & other_user.project_type_tags
    score += common_projects.length * 15
    
    # Availability overlap (simplified - could be enhanced)
    score += 20 if availability == other_user.availability
    
    score
  end
end
