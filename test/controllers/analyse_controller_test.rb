require "test_helper"

class AnalyseControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive",
                                          analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-card", text: /Going well/
    assert_select ".analysis-card", text: /Onboarding overwhelming/
  end

  test "refresh regenerates the insight synchronously and flashes success" do
    loop_record = analysable_loop_with_points
    fake = { "overall_sentiment" => "positive", "summary" => "Trending up", "themes" => [], "feature_requests" => [] }

    stub_instance_method(LlmClient, :complete, ->(**) { fake }) do
      post refresh_analyse_path(loop_record.slug)
    end

    assert_redirected_to analyse_path(loop_record.slug)
    assert_equal "positive", loop_record.reload.insight.overall_sentiment
  end

  test "refresh flashes an error when the LLM fails" do
    loop_record = analysable_loop_with_points

    stub_instance_method(LlmClient, :complete, ->(**) { raise LlmClient::Error, "boom" }) do
      post refresh_analyse_path(loop_record.slug)
    end

    assert_redirected_to analyse_path(loop_record.slug)
    assert_match(/couldn.t|failed|try again/i, flash[:alert])
  end

  test "refresh flashes a notice and skips the LLM call when nothing is analyzed" do
    loop_record = @user.loops.create!(name: "L")

    stub_instance_method(LlmClient, :complete, ->(**) { raise "should not be called" }) do
      post refresh_analyse_path(loop_record.slug)
    end

    assert_redirected_to analyse_path(loop_record.slug)
    assert_match(/nothing to analyze/i, flash[:alert])
    assert_nil loop_record.reload.insight
  end

  test "backfill enqueues one Stage 1 job per pending feedback" do
    loop_record = analysable_loop_with_points
    Feedback.create!(loop: loop_record, transcript: "unanalyzed one")

    assert_enqueued_jobs 1, only: AnalyzeFeedbackJob do
      post backfill_analyse_path(loop_record.slug)
    end
    assert_redirected_to analyse_path(loop_record.slug)
  end

  private

  def analysable_loop_with_points
    loop_record = @user.loops.create!(name: "L")
    points = { "points" => [{ "kind" => "theme", "title" => "t", "quote" => "q" }] }
    loop_record.feedbacks.create!(transcript: "hi", extracted_points: points)
    loop_record
  end
end
