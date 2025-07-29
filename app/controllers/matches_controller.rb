class MatchesController < ApplicationController
  before_action :authenticate_user!

  # GET /match
  def index
    @candidate = User
      .where.not(id: current_user.id)
      .order(Arel.sql('RANDOM()'))
      .first
  end

  # POST /match/:id/:type
  def swipe
    @target = User.find(params[:id])
  
    # Persist the swipe
    Match.create!(
      user:   current_user,
      target: @target,
      kind:   params[:type]
    )
  
    flash[:notice] =
      if params[:type] == 'connect'
        "You connected with #{@target.name}!"
      else
        "You passed on #{@target.name}."
      end
  
    redirect_to next_match_path
  end
  
  def dashboard
    @connections = current_user.matches
                               .where(kind: 'connect')
                               .includes(:target)
    @passes      = current_user.matches
                               .where(kind: 'pass')
                               .includes(:target)
  end
  
end
