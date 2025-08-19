class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team, only: [:show, :edit, :update, :join, :leave, :add_member, :remove_member, :chat]
  before_action :ensure_team_access, only: [:show, :edit, :update, :add_member, :remove_member, :chat]
  before_action :ensure_team_admin, only: [:edit, :update, :add_member, :remove_member]

  # GET /teams
  # Shows all teams the user can join or is part of
  def index
    @my_teams = current_user.active_teams.includes(:members, :creator)
    @available_teams = Team.forming
                          .by_university(current_user.university)
                          .where.not(id: current_user.teams.select(:id))
                          .includes(:creator, :members)
                          .limit(10)

    respond_to do |format|
      format.html
      format.json { 
        render json: {
          my_teams: @my_teams.map { |team| team_json(team) },
          available_teams: @available_teams.map { |team| team_json(team) }
        }
      }
    end
  end

  # GET /teams/new
  # Form to create a new team
  def new
    @team = Team.new
    @project_types = %w[academic startup research hackathon competition other]
  end

  # POST /teams
  # Creates a new team
  def create
    @team = current_user.created_teams.build(team_params)
    
    if @team.save
      # Add creator as first member
      @team.add_member(current_user, role: 'creator')
      
      flash[:notice] = "Team '#{@team.name}' created successfully!"
      redirect_to @team
    else
      @project_types = %w[academic startup research hackathon competition other]
      render :new, status: :unprocessable_entity
    end
  end

  # GET /teams/:id
  # Shows team details
  def show
    @members = @team.members.includes(:team_memberships)
    @pending_invitations = @team.matches.pending.includes(:user)
    
    respond_to do |format|
      format.html
      format.json { render json: team_json(@team) }
    end
  end

  # GET /teams/:id/edit
  # Form to edit team
  def edit
    @project_types = %w[academic startup research hackathon competition other]
  end

  # PATCH /teams/:id
  # Updates team
  def update
    if @team.update(team_params)
      flash[:notice] = "Team updated successfully!"
      redirect_to @team
    else
      @project_types = %w[academic startup research hackathon competition other]
      render :edit, status: :unprocessable_entity
    end
  end

  # POST /teams/:id/join
  # User joins a team
  def join
    if @team.full?
      flash[:alert] = "This team is full."
      redirect_to @team
      return
    end

    if @team.add_member(current_user)
      flash[:notice] = "You've joined '#{@team.name}'!"
    else
      flash[:alert] = "Could not join team."
    end
    
    redirect_to @team
  end

  # POST /teams/:id/leave
  # User leaves a team
  def leave
    if @team.creator == current_user
      flash[:alert] = "Team creators cannot leave. Transfer ownership first."
      redirect_to @team
      return
    end

    if @team.remove_member(current_user)
      flash[:notice] = "You've left '#{@team.name}'."
      redirect_to teams_path
    else
      flash[:alert] = "Could not leave team."
      redirect_to @team
    end
  end

  # POST /teams/:id/add_member
  # Admin adds a member to team
  def add_member
    user = User.find(params[:user_id])
    
    if @team.add_member(user, role: params[:role] || 'member')
      flash[:notice] = "#{user.display_name} added to team!"
    else
      flash[:alert] = "Could not add member to team."
    end
    
    redirect_to @team
  end

  # POST /teams/:id/remove_member
  # Admin removes a member from team
  def remove_member
    user = User.find(params[:user_id])
    
    if user == @team.creator
      flash[:alert] = "Cannot remove team creator."
      redirect_to @team
      return
    end

    if @team.remove_member(user)
      flash[:notice] = "#{user.display_name} removed from team."
    else
      flash[:alert] = "Could not remove member from team."
    end
    
    redirect_to @team
  end

  # GET /teams/:id/chat
  # Team chat interface
  def chat
    @members = @team.members.includes(:team_memberships)
    
    respond_to do |format|
      format.html
      format.json { render json: { team: team_json(@team), members: @members.map { |m| member_json(m) } } }
    end
  end

  private

  def set_team
    @team = Team.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "Team not found."
    redirect_to teams_path
  end

  def ensure_team_access
    unless @team.member?(current_user) || @team.status == 'forming'
      flash[:alert] = "You don't have access to this team."
      redirect_to teams_path
    end
  end

  def ensure_team_admin
    unless @team.admin?(current_user)
      flash[:alert] = "You don't have permission to perform this action."
      redirect_to @team
    end
  end

  def team_params
    params.require(:team).permit(
      :name, :description, :project_type, :max_members, :university,
      :project_deadline, :meeting_schedule, :required_skills, :tags,
      :communication_channels
    )
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
      university: team.university,
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
      meeting_schedule: team.meeting_schedule,
      communication_channels: team.communication_channels,
      full: team.full?,
      skills_complete: team.skills_complete?,
      skill_gaps: team.skill_gaps
    }
  end

  # JSON representation of a team member
  def member_json(member)
    {
      id: member.id,
      name: member.display_name,
      role: @team.team_memberships.find_by(user: member)&.role,
      joined_at: @team.team_memberships.find_by(user: member)&.joined_at,
      skills: member.skill_tags,
      university: member.university,
      degree_program: member.degree_program,
      year_of_study: member.year_of_study
    }
  end
end

