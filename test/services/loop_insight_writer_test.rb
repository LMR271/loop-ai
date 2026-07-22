require "test_helper"

class LoopInsightWriterTest < ActiveSupport::TestCase
  test "rebuilds the insight graph with themes, requests, and quotes" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder, organization: founder.owned_organization)
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    result = {
      "overall_sentiment" => "positive", "summary" => "Going well",
      "themes" => [{ "title" => "Onboarding", "description" => "hard start", "mention_count" => 1,
                     "sentiment" => "frustrated", "citations" => [{ "feedback_id" => feedback.id, "quote" => "too many features" }] }],
      "feature_requests" => [{ "title" => "Walkthrough", "description" => "guided", "citations" => [] }]
    }

    LoopInsightWriter.new(loop_record, result, 1).call

    insight = loop_record.reload.insight
    assert_equal "positive", insight.overall_sentiment
    assert_equal 1, insight.analyzed_feedback_count
    theme = insight.themes.first
    assert_equal "Onboarding", theme.title
    assert_equal "too many features", theme.quotes.first.text
    assert_equal feedback, theme.quotes.first.feedback
  end

  test "replaces a prior analysis rather than appending" do
    founder = User.create!(email: "founder2@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder, organization: founder.owned_organization)
    empty = { "overall_sentiment" => "neutral", "summary" => "", "themes" => [], "feature_requests" => [] }
    LoopInsightWriter.new(loop_record, empty.merge("summary" => "first"), 0).call
    LoopInsightWriter.new(loop_record, empty.merge("summary" => "second"), 0).call

    assert_equal 1, Insight.where(loop: loop_record).count
    assert_equal "second", loop_record.reload.insight.summary
  end
end
