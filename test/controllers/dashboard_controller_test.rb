require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "navbar bell shows the count of new responses across loops" do
    loop_record = @user.loops.create!(name: "L")
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }
    loop_record.create_insight!(analyzed_feedback_count: 0)

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "2"
  end

  test "saving exactly 4 stat keys updates the preference" do
    keys = %w[active_loops draft_loops closed_loops total_loops]

    patch dashboard_stat_preferences_path, params: { stat_keys: keys }

    assert_redirected_to dashboard_path
    assert_equal keys, @user.reload.dashboard_stat_keys
  end

  test "saving fewer than 4 stat keys is rejected and leaves preferences unchanged" do
    @user.update!(dashboard_stat_keys: %w[active_loops draft_loops closed_loops total_loops])

    patch dashboard_stat_preferences_path, params: { stat_keys: %w[active_loops draft_loops] }

    assert_redirected_to dashboard_path
    assert_equal "Select exactly 4 stats to save.", flash[:alert]
    assert_equal %w[active_loops draft_loops closed_loops total_loops], @user.reload.dashboard_stat_keys
  end
end
