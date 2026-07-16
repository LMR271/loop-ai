class TeamMailer < ApplicationMailer
  def invite(team_member)
    @team_member = team_member
    @invitation_url = invitation_url(invitation_token: team_member.invitation_token)

    mail to: team_member.email, subject: "You've been invited to join a LoopAI workspace"
  end
end
