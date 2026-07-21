require "test_helper"

class AnalyseControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "refresh enqueues the loop analysis" do
    loop_record = @user.loops.create!(name: "L")
    assert_enqueued_with(job: AnalyzeLoopJob) do
      post refresh_analyse_path(loop_record.slug)
    end
    assert_redirected_to analyse_path(loop_record.slug)
  end

  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-summary-card", text: /Going well/
    assert_select ".theme-card", text: /Onboarding overwhelming/
  end
end
