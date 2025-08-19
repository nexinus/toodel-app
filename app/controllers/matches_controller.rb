class MatchesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:show, :chat, :team_chat]
  before_action :ensure_profile_complete, only: [:discover, :invite, :skip, :create]

  # GET /matches
  # Shows all matches and team invitations for the current user
  def index
    @pending_invitations = current_user.pending_invitations.includes(:user, :team)
    @accepted_invitations = current_user.accepted_invitations.includes(:user, :team)
    @mutual_matches = current_user.mutual_matches
    @my_teams = current_user.active_teams.includes(:members, :creator)
    # Backwards compat for views expecting @matches
    @matches = @mutual_matches

    respond_to do |format|
      format.html
      format.json { 
        render json: {
          pending_invitations: @pending_invitations.map { |match| match_json(match) },
          accepted_invitations: @accepted_invitations.map { |match| match_json(match) },
          mutual_matches: @mutual_matches.map { |match| match_json(match) },
          teams: @my_teams.map { |team| team_json(team) }
        }
      }
    end
  end

  # POST /matches
  # Creates a new match/invitation from a swipe style payload
  # Expected params: { target_id:, action_type: 'invite'|'skip', team_id?, invitation_message?, project_context? }
  def create
    begin
      target = User.find(params[:target_id])
    rescue ActiveRecord::RecordNotFound
      flash[:alert] = "User not found."
      redirect_to discover_path
      return
    end
    
    action = params[:action_type] || 'invite'
    # Normalize action to valid values
    action = %w[invite skip].include?(action.to_s.downcase) ? action.to_s.downcase : 'invite'

    existing_match = Match.find_by(user: current_user, target: target, team_id: params[:team_id])
    if existing_match
      return render json: { error: "Already interacted" }, status: :unprocessable_entity if request.format.json?
      flash[:alert] = "You already interacted with this user."
      redirect_to discover_path
      return
    end

    match = Match.create!(
      user: current_user,
      target: target,
      action_type: action,
      swiped_at: Time.current,
      team_id: params[:team_id],
      invitation_message: params[:invitation_message],
      project_context: params[:project_context]
    )

    if match.persisted? && action == 'invite' && match.mutual_invitation?
      notify_mutual_invitation(match)
    end

    respond_to do |format|
      format.html do
        flash[:notice] = action == 'invite' ? "Invitation sent to #{target.display_name}." : "Skipped #{target.display_name}."
        redirect_to discover_path
      end
      format.json { render json: match_json(match), status: :created }
    end
  end

  # GET /discover
  # Shows potential teammates based on compatibility algorithm
  def discover
    @filters = discover_filters
    @candidates = find_compatible_candidates(@filters)
    @current_candidate = @candidates.first
    
    # Get user's active teams for context
    @my_teams = current_user.active_teams.includes(:members)
    
    respond_to do |format|
      format.html
      format.json { render json: @candidates.map { |user| candidate_json(user) } }
    end
  end

  # GET /matches/:id
  # Shows details of a specific match/invitation
  def show
    @match = current_user.matches.find(params[:id])
    @other_user = @match.other_user(current_user)
    @matched_user = @match.target
    @team = @match.team
    
    # Check if this can form a team
    @can_form_team = @match.can_form_team?
    
    respond_to do |format|
      format.html
      format.json { render json: match_json(@match) }
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Match not found."
    redirect_to matches_path
  end

  # GET /matches/:id/chat
  # Prepares for one-on-one chat with a matched user
  def chat
    @match = current_user.matches.find(params[:id])
    @other_user = @match.other_user(current_user)
    
    # Ensure this is a mutual invitation before allowing chat
    unless @match.mutual_invitation?
      flash[:alert] = "You can only chat with users you've mutually invited."
      redirect_to matches_path
      return
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Match not found."
    redirect_to matches_path
  end

  # GET /matches/:id/team_chat
  # Prepares for team chat if the match involves a team
  def team_chat
    @match = current_user.matches.find(params[:id])
    @team = @match.team
    
    unless @team && @match.can_form_team?
      flash[:alert] = "Team chat is only available for team-based matches."
      redirect_to matches_path
      return
    end
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Match not found."
    redirect_to matches_path
  end

  # POST /matches/:id/invite
  # Records an invitation action for a specific target
  def invite
    @target = User.find(params[:id])
    
    # Prevent duplicate actions
    existing_match = Match.find_by(
      user: current_user, 
      target: @target, 
      team_id: params[:team_id]
    )
    
    if existing_match
      flash[:alert] = "You already interacted with this user."
      redirect_to discover_path
      return
    end

    match_params = {
      user: current_user,
      target: @target,
      action_type: 'invite',
      swiped_at: Time.current,
      team_id: params[:team_id]
    }
    
    if params[:invitation_message].present?
      match_params[:invitation_message] = params[:invitation_message]
    end
    
    if params[:project_context].present?
      match_params[:project_context] = params[:project_context]
    end

    match = Match.create!(match_params)

    if match.persisted?
      if match.mutual_invitation?
        # It's a mutual invitation!
        notify_mutual_invitation(match)
        flash[:notice] = "🎉 #{@target.display_name} also invited you! You can now chat and form a team!"
      else
        flash[:notice] = "Invitation sent to #{@target.display_name}! Waiting for their response."
      end
    else
      flash[:alert] = "Could not save your invitation: #{match.errors.full_messages.to_sentence}"
    end

    redirect_to discover_path
  end

  # POST /matches/:id/skip
  # Records a skip action for a specific target
  def skip
    @target = User.find(params[:id])
    
    # Prevent duplicate actions
    existing_match = Match.find_by(
      user: current_user, 
      target: @target, 
      team_id: params[:team_id]
    )
    
    if existing_match
      flash[:alert] = "You already interacted with this user."
      redirect_to discover_path
      return
    end

    match = Match.create!(
      user: current_user,
      target: @target,
      action_type: 'skip',
      swiped_at: Time.current,
      team_id: params[:team_id]
    )

    if match.persisted?
      flash[:notice] = "Skipped #{@target.display_name}."
    else
      flash[:alert] = "Could not save your action: #{match.errors.full_messages.to_sentence}"
    end

    redirect_to discover_path
  end

  # POST /matches/:id/accept
  # Accept an invitation
  def accept
    @match = Match.find(params[:id])
    
    unless @match.can_interact?(current_user)
      flash[:alert] = "You cannot accept this invitation."
      redirect_to matches_path
      return
    end

    @match.accept!

    # Find if reciprocal invite/accept exists
    reciprocal = Match.find_by(user: current_user, target: @match.user)
    unless reciprocal
      reciprocal = Match.create!(
        user: current_user,
        target: @match.user,
        action_type: 'invite',
        status: 'accepted',
        swiped_at: Time.current
      )
    end
    
    # Log the acceptance for debugging
    Rails.logger.info "User #{current_user.id} accepted invitation from #{@match.user.id}"
    
    # Check if this creates a mutual match
    if @match.mutual_invitation?
      notify_mutual_invitation(@match)
      Rails.logger.info "🎉 Mutual match created between #{current_user.id} and #{@match.user.id}!"
      flash[:notice] = "🎉 It's a mutual match! You can now chat with #{@match.user.display_name}."
    else
      flash[:notice] = "Invitation accepted! Waiting for #{@match.user.display_name} to accept your invitation."
    end
    
    if @match.can_form_team?
      flash[:notice] = "Invitation accepted! You're now part of the team."
    else
      flash[:notice] = "Invitation accepted! You can now chat with #{@match.user.display_name}."
    end
    
    redirect_to matches_path
  end

  # POST /matches/:id/decline
  # Decline an invitation
  def decline
    @match = Match.find(params[:id])
    
    unless @match.can_interact?(current_user)
      flash[:alert] = "You cannot decline this invitation."
      redirect_to matches_path
      return
    end

    @match.decline!
    flash[:notice] = "Invitation declined."
    redirect_to matches_path
  end

  # GET /dashboard
  # Shows comprehensive dashboard with teams, invitations, and stats
  def dashboard
    @pending_invitations = current_user.pending_invitations.includes(:user, :team)
    @accepted_invitations = current_user.accepted_invitations.includes(:user, :team)
    @mutual_matches = current_user.mutual_matches
    @my_teams = current_user.active_teams.includes(:members, :creator)
    @recent_matches = current_user.matches.recent_first.limit(5).includes(:user, :target, :team)
    
    # Stats
    @total_invitations = current_user.matches.invitations.count
    @accepted_count = current_user.accepted_invitations.count
    @team_count = @my_teams.count
    @compatibility_score = current_user.compatibility_score_with(User.first) # Placeholder

    respond_to do |format|
      format.html
      format.json { 
        render json: {
          pending_invitations: @pending_invitations.map { |match| match_json(match) },
          accepted_invitations: @accepted_invitations.map { |match| match_json(match) },
          mutual_matches: @mutual_matches.map { |match| match_json(match) },
          teams: @my_teams.map { |team| team_json(team) },
          stats: {
            total_invitations: @total_invitations,
            accepted_count: @accepted_count,
            team_count: @team_count
          }
        }
      }
    end
  end

  private

  def set_user
    @user = current_user
  end

  def ensure_profile_complete
    unless current_user.full_profile?
      flash[:alert] = "Please complete your profile before discovering teammates."
      redirect_to edit_user_registration_path
    end
  end

  # Find compatible candidates based on filters and compatibility algorithm
  def find_compatible_candidates(filters)
    candidates = User.looking_for_teammates
                     .where.not(id: current_user.id)
                     .where.not(id: current_user.matches.select(:target_id))
    
    # Apply filters
    candidates = candidates.by_university(filters[:university]) if filters[:university].present?
    candidates = candidates.by_project_type(filters[:project_type]) if filters[:project_type].present?
    candidates = candidates.with_skills(filters[:skills]) if filters[:skills].present?
    
    # Calculate compatibility scores and sort
    candidates_with_scores = candidates.map do |candidate|
      {
        user: candidate,
        score: current_user.compatibility_score_with(candidate)
      }
    end
    
    # Sort by compatibility score (highest first)
    candidates_with_scores.sort_by { |c| -c[:score] }
                         .map { |c| c[:user] }
                         .first(20) # Limit to top 20
  end

  def discover_filters
    {
      university: params[:university],
      project_type: params[:project_type],
      skills: params[:skills]&.split(',')&.map(&:strip)
    }
  end

  # Notify users about mutual invitations
  def notify_mutual_invitation(match)
    # Broadcast to both users via ActionCable
    ActionCable.server.broadcast(
      "mutual_invitations_#{match.user.id}",
      { 
        target: match.target.display_name, 
        target_id: match.target.id,
        match_id: match.id,
        team_id: match.team_id,
        message: "🎉 You and #{match.target.display_name} have mutually invited each other!"
      }
    )
    
    ActionCable.server.broadcast(
      "mutual_invitations_#{match.target.id}",
      { 
        target: match.user.display_name, 
        target_id: match.user.id,
        match_id: match.id,
        team_id: match.team_id,
        message: "🎉 You and #{match.user.display_name} have mutually invited each other!"
      }
    )
  end

  # JSON representation of a match for API responses
  def match_json(match)
    {
      id: match.id,
      user: {
        id: match.user.id,
        name: match.user.display_name,
        university: match.user.university,
        degree_program: match.user.degree_program,
        year_of_study: match.user.year_of_study,
        skills: match.user.skill_tags
      },
      target: {
        id: match.target.id,
        name: match.target.display_name,
        university: match.target.university,
        degree_program: match.target.degree_program,
        year_of_study: match.target.year_of_study,
        skills: match.target.skill_tags
      },
      action_type: match.action_type,
      status: match.status,
      swiped_at: match.swiped_at,
      invitation_message: match.invitation_message,
      project_context: match.project_context,
      team_id: match.team_id,
      mutual_invitation: match.mutual_invitation?,
      can_form_team: match.can_form_team?,
      chat_url: match.mutual_invitation? ? chat_match_path(match) : nil,
      team_chat_url: match.can_form_team? ? team_chat_match_path(match) : nil
    }
  end

  # JSON representation of a candidate for discovery
  def candidate_json(candidate)
    {
      id: candidate.id,
      name: candidate.display_name,
      university: candidate.university,
      degree_program: candidate.degree_program,
      year_of_study: candidate.year_of_study,
      skills: candidate.skill_tags,
      project_types: candidate.project_type_tags,
      availability: candidate.availability,
      compatibility_score: current_user.compatibility_score_with(candidate),
      profile_completeness: candidate.full_profile? ? 100 : 75
    }
  end

  # JSON representation of a team
  def team_json(team)
    {
      id: team.id,
      name: team.name,
      description: team.description,
      project_type: team.project_type,
      status: team.status,
      max_members: team.max_members,
      current_members: team.members.count,
      creator: {
        id: team.creator.id,
        name: team.creator.display_name
      },
      members: team.members.map { |member|
        {
          id: member.id,
          name: member.display_name,
          role: team.team_memberships.find_by(user: member)&.role
        }
      },
      required_skills: team.required_skills,
      tags: team.tags,
      project_deadline: team.project_deadline,
      meeting_schedule: team.meeting_schedule
    }
  end
end
