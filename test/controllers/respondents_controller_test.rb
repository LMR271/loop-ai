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

  # TODO(human): add a test for the closed path.
  # The controller renders `:closed` unless the loop is `active?`. Create a loop
  # with status: :draft (or flip @loop) and assert what the respondent sees when
  # the loop isn't open. Decide what to assert on — status code alone won't
  # distinguish show from closed, since both return 200. What in the closed page
  # is unique enough to assert against?
end
