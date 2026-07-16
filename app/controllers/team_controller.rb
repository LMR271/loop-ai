class TeamController < ApplicationController
  before_action :require_workspace_admin!

  def index
    @team_members = current_workspace_owner.team_memberships.order(created_at: :desc)
    @team_member = Team.new
  end

  def create
    @team_member = current_workspace_owner.team_memberships.build(team_member_params)

    if @team_member.save
      @team_member.update!(invitation_sent_at: Time.current)
      TeamMailer.invite(@team_member).deliver_later
      redirect_to team_path, notice: "Invitation sent to #{@team_member.email}."
    else
      @team_members = current_workspace_owner.team_memberships.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    current_workspace_owner.team_memberships.find(params[:id]).destroy!
    redirect_to team_path, notice: "Access revoked."
  end

  private

  def team_member_params
    params.require(:team).permit(:email, :role)
  end
end
