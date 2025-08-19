class Match < ApplicationRecord
  belongs_to :user
  belongs_to :target, class_name: 'User'
  belongs_to :team, optional: true

  scope :recent_first, -> { order(swiped_at: :desc) }
  scope :invitations, -> { where(action_type: 'invite') }
  scope :skips, -> { where(action_type: 'skip') }
  scope :pending, -> { where(status: 'pending') }
  scope :accepted, -> { where(status: 'accepted') }
  scope :declined, -> { where(status: 'declined') }

  validates :action_type, inclusion: { in: %w[invite skip] }
  validates :status, inclusion: { in: %w[pending accepted declined withdrawn] }
  validates :target_id, uniqueness: { scope: [:user_id, :team_id] }
  
  # Check if this is a mutual invitation (both users invited each other)
  def mutual_invitation?
    return false unless action_type == 'invite'
    
    Match.exists?(
      user: target,
      target: user,
      action_type: 'invite',
      status: 'accepted'
    )
  end

  # Check if this invitation can form a team
  def can_form_team?
    mutual_invitation? && team.present?
  end

  # Accept an invitation
  def accept!
    Rails.logger.info "Attempting to accept match #{id}, current status: #{status}"
    result = update!(status: 'accepted')
    Rails.logger.info "Update result: #{result}, new status: #{status}"
    
    # If this is a mutual invitation and there's a team, add user to team
    if mutual_invitation? && team.present?
      team.add_member(user)
    end
  end

  # Decline an invitation
  def decline!
    update!(status: 'declined')
  end

  # Withdraw an invitation
  def withdraw!
    update!(status: 'withdrawn')
  end

  # Get the other user in this match
  def other_user(current_user)
    current_user == user ? target : user
  end

  # Check if user can interact with this match
  def can_interact?(user)
    return false unless user
    return false if status != 'pending'
    
    # Users can only interact with invitations sent to them
    user == target
  end
end
