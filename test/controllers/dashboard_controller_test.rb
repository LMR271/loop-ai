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

  test "navbar bell drops to zero once the current user has viewed the loop" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyze_path(loop_record.slug)

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", count: 0
  end

  test "navbar bell only counts feedback that arrived after the user last viewed the loop" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "first")
    get analyze_path(loop_record.slug)
    Feedback.create!(loop: loop_record, transcript: "second")

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "1"
  end

  test "account menu includes a dark/light mode toggle showing the mode it will switch to" do
    get dashboard_path

    assert_select "nav[data-controller='theme']" do
      assert_select "button[data-action='click->theme#toggle']" do
        assert_select "[data-theme-target='icon'].fa-moon"
        assert_select "[data-theme-target='label']", text: "Dark mode"
      end
    end
  end
end
