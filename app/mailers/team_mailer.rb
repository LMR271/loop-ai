class TeamMailer < ApplicationMailer
  def invite(team_member)
    @team_member = team_member
    @invitation_url = invitation_url(invitation_token: team_member.invitation_token)
    @workspace_possessive = workspace_possessive(team_member.organization)

    mail to: team_member.email, from: ALERTS_SENDER, reply_to: "hi@getloop.me",
         subject: "You've been invited to join #{@workspace_possessive} Loop AI workspace"
  end

  def welcome(team_member)
    @team_member = team_member
    @workspace_possessive = workspace_possessive(team_member.organization)

    mail to: team_member.user.email, subject: "Welcome to #{@workspace_possessive} Loop AI workspace"
  end

  private

  # "Acme's" / "your new" -- organization name isn't collected everywhere yet
  # (accounts created before it existed, or via the teammate-invite path).
  def workspace_possessive(organization)
    organization.name.presence ? "#{organization.name}'s" : "your new"
  end
end
