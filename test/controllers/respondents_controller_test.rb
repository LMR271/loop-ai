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

  test "show shows a generic public intro but names the loop in the tab title" do
    get respondent_url(@loop.slug)

    assert_response :success
    # The on-page copy stays generic (no internal loop name in the visible body)...
    assert_select ".respondent-card__title", text: "Share your feedback"
    # ...but the browser tab title names it, so an owner with several tabs open can tell them apart.
    assert_select "title", "Share your feedback - Onboarding feedback"
  end

  test "show renders the orb start control and a hidden thank-you block" do
    get respondent_url(@loop.slug)

    assert_response :success
    assert_match(/class="[^"]*\borb\b/, response.body)
    assert_match(/data-interview-target="thankYou"/, response.body)
    assert_match(/you can close this tab/i, response.body)
  end

  test "favicon defaults to the Loop AI icon when no organization logo is uploaded" do
    get respondent_url(@loop.slug)

    assert_response :success
    assert_select "link[rel=icon][href='/icon.png']", 1
    assert_select "link[rel=icon][href='/icon.svg']", 1
  end

  test "favicon uses the organization logo when one is uploaded" do
    @user.organization.logo.attach(io: StringIO.new("fake image bytes"), filename: "logo.png", content_type: "image/png")

    get respondent_url(@loop.slug)

    assert_response :success
    assert_select "link[rel=icon][href='/icon.png']", 0
    assert_select "link[rel=icon]", 1
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
