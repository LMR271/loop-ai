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
end
