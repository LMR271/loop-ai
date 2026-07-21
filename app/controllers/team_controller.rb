class TeamController < ApplicationController
  before_action :require_workspace_admin!, only: %i[create update destroy]

  def index
    @team_members = current_organization.team_memberships.order(created_at: :desc)
    @team_member = Team.new
  end

  def create
    @team_member = current_organization.team_memberships.build(team_member_params)

    if @team_member.save
      @team_member.update!(invitation_sent_at: Time.current)
      TeamMailer.invite(@team_member).deliver_later
      redirect_to team_path, notice: "Invitation sent to #{@team_member.email}."
    else
      @team_members = current_organization.team_memberships.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    team_member = current_organization.team_memberships.find(params[:id])
    team_member.update!(team_member_params.slice(:role))
    redirect_to team_path, notice: "Role updated for #{team_member.email}."
  end

  def destroy
    current_organization.team_memberships.find(params[:id]).destroy!
    redirect_to team_path, notice: "Access revoked."
  end

  private

  def team_member_params
    params.require(:team).permit(:email, :role)
  end
end
