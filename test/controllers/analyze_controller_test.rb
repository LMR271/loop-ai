require "test_helper"

class AnalyzeControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "refresh enqueues the loop analysis" do
    loop_record = @user.loops.create!(name: "L")
    assert_enqueued_with(job: AnalyzeLoopJob) do
      post refresh_analyze_path(loop_record.slug)
    end
    assert_redirected_to analyze_path(loop_record.slug)
  end

  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-summary-card", text: /Going well/
    assert_select ".theme-card", text: /Onboarding overwhelming/
  end

  test "visiting a loop's page marks its notifications seen, clearing the navbar bell" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    assert_equal 1, loop_record.unseen_feedback_count

    get analyze_path(loop_record.slug)

    assert_equal 0, loop_record.reload.unseen_feedback_count
  end
end
