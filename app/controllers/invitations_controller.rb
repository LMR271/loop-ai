class InvitationsController < ApplicationController
  skip_before_action :authenticate_user!
  before_action :set_team_member

  def show
    @user = User.new
  end

  def update
    return redirect_to new_user_session_path, alert: existing_account_alert if User.exists?(email: @team_member.email)

    # skip_confirmation! - they already proved the address by opening this invite email
    @user = User.new(user_params.merge(email: @team_member.email)).tap(&:skip_confirmation!)

    if @user.save
      @team_member.update!(user: @user, invitation_accepted_at: Time.current)
      TeamMailer.welcome(@team_member).deliver_later
      sign_in(@user)
      redirect_to dashboard_path, notice: "Welcome to the team!"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def existing_account_alert
    "An account with this email already exists. Log in, then ask an admin to resend your invite."
  end

  def set_team_member
    @team_member = Team.find_by(invitation_token: params[:invitation_token])
    return redirect_to new_user_session_path, alert: "This invitation link is invalid." if @team_member.nil?
    return unless @team_member.accepted?

    redirect_to new_user_session_path, alert: "This invitation has already been accepted."
  end

  def user_params
    params.require(:user).permit(:name, :password, :password_confirmation)
  end
end
