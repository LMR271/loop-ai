class TeamMailer < ApplicationMailer
  def invite(team_member)
    @team_member = team_member
    @invitation_url = invitation_url(invitation_token: team_member.invitation_token)
    @workspace_possessive = workspace_possessive(team_member.account_owner)

    mail to: team_member.email, from: ALERTS_SENDER, reply_to: "hi@getloop.me",
         subject: "You've been invited to join #{@workspace_possessive} Loop AI workspace"
  end

  def welcome(team_member)
    @team_member = team_member
    @workspace_possessive = workspace_possessive(team_member.account_owner)

    mail to: team_member.user.email, subject: "Welcome to #{@workspace_possessive} Loop AI workspace"
  end

  private

  # "Acme's" / "your new" -- organization_name isn't collected everywhere yet
  # (accounts created before it existed, or via the teammate-invite path).
  def workspace_possessive(account_owner)
    account_owner.organization_name.presence ? "#{account_owner.organization_name}'s" : "your new"
  end
end
