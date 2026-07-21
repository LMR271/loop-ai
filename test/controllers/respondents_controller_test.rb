require "test_helper"

class RespondentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "owner@example.com", password: "password123")
    @loop = @user.loops.create!(name: "Onboarding feedback", status: :active)
  end

  test "show renders for an active loop without authentication" do
    get respondent_url(@loop.slug)

    assert_response :success
  end

  test "show renders without app chrome (no login/signup links)" do
    get respondent_url(@loop.slug)

    assert_response :success
    assert_no_match(/Sign up/, response.body)
    assert_no_match(/Log in/, response.body)
  end

  test "show hides the internal loop name and shows a generic public intro" do
    get respondent_url(@loop.slug)

    assert_response :success
    assert_no_match(/Onboarding feedback/, response.body) # internal name must not leak
    assert_match(/Share your feedback/, response.body)    # generic public intro
  end

  test "show renders the orb start control and a hidden thank-you block" do
    get respondent_url(@loop.slug)

    assert_response :success
    assert_match(/class="[^"]*\borb\b/, response.body)
    assert_match(/data-interview-target="thankYou"/, response.body)
    assert_match(/you can close this tab/i, response.body)
  end

  test "signed_url returns not_found for an active loop without a provisioned agent" do
    # Seeded (or otherwise not-yet-provisioned) loops can be active with a nil
    # agent_id. The controller must not hand that nil to ElevenLabs, which 404s
    # and would surface as a 500 — it should short-circuit to not_found instead.
    @loop.update!(agent_id: nil)

    get respondent_signed_url_url(@loop.slug)

    assert_response :not_found
  end

  # TODO(human): add a test for the closed path.
  # The controller renders `:closed` unless the loop is `active?`. Create a loop
  # with status: :draft (or flip @loop) and assert what the respondent sees when
  # the loop isn't open. Decide what to assert on — status code alone won't
  # distinguish show from closed, since both return 200. What in the closed page
  # is unique enough to assert against?
end
