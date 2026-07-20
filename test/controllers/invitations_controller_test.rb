require "test_helper"

class InvitationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "founder@example.com", password: "password123", name: "Jamie Founder")
    @team_member = @owner.team_memberships.create!(email: "teammate@example.com", role: :editor)
  end

  test "show renders the accept-invite form for a pending invitation" do
    get invitation_path(@team_member.invitation_token)

    assert_response :success
  end

  test "show redirects for an unknown invitation token" do
    get invitation_path("not-a-real-token")

    assert_redirected_to new_user_session_path
  end

  test "show redirects for an already-accepted invitation" do
    @team_member.update!(user: @owner, invitation_accepted_at: Time.current)

    get invitation_path(@team_member.invitation_token)

    assert_redirected_to new_user_session_path
  end

  test "update creates the account, accepts the invite, signs in, and sends a welcome email" do
    patch invitation_path(@team_member.invitation_token), params: {
      user: { name: "Alex Teammate", password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to dashboard_path

    @team_member.reload
    assert @team_member.accepted?
    assert_equal "teammate@example.com", @team_member.user.email

    welcome_job = enqueued_jobs.find { |job| job[:args].first == "TeamMailer" }
    assert welcome_job, "expected a TeamMailer delivery job to be enqueued"
    assert_equal "welcome", welcome_job[:args][1]
  end

  test "update rejects the invite when an account with that email already exists" do
    User.create!(email: "teammate@example.com", password: "password123")

    patch invitation_path(@team_member.invitation_token), params: {
      user: { name: "Alex Teammate", password: "password123", password_confirmation: "password123" }
    }

    assert_redirected_to new_user_session_path
    assert_not @team_member.reload.accepted?
  end
end
