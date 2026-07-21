require "test_helper"

class TeamMailerTest < ActionMailer::TestCase
  test "invite emails the invited address with a link to accept and the org name" do
    owner = User.create!(email: "founder@example.com", password: "password123", organization_name: "Acme")
    team_member = owner.team_memberships.create!(email: "teammate@example.com", role: :editor)

    mail = TeamMailer.invite(team_member)

    assert_equal ["teammate@example.com"], mail.to
    assert_equal "You've been invited to join Acme's Loop AI workspace", mail.subject
    assert_equal ["alerts@getloop.me"], mail.from
    assert_equal ["hi@getloop.me"], mail.reply_to
    assert_match "/invitations/#{team_member.invitation_token}", mail.body.encoded
  end

  test "invite falls back to generic wording when the owner has no organization name yet" do
    owner = User.create!(email: "founder@example.com", password: "password123")
    team_member = owner.team_memberships.create!(email: "teammate@example.com", role: :editor)

    mail = TeamMailer.invite(team_member)

    assert_equal "You've been invited to join your new Loop AI workspace", mail.subject
  end

  test "welcome greets the newly joined teammate with the org name" do
    owner = User.create!(email: "founder@example.com", password: "password123", organization_name: "Acme")
    joined_user = User.create!(email: "teammate@example.com", password: "password123", name: "Alex Teammate")
    team_member = owner.team_memberships.create!(
      email: "teammate@example.com", role: :editor, user: joined_user, invitation_accepted_at: Time.current
    )

    mail = TeamMailer.welcome(team_member)

    assert_equal ["teammate@example.com"], mail.to
    assert_equal "Welcome to Acme's Loop AI workspace", mail.subject
    assert_equal ["hi@getloop.me"], mail.from
    assert_match "Alex Teammate", mail.body.encoded
    assert_match "editor", mail.body.encoded
  end
end
