require "test_helper"

class AnalyzeHelperTest < ActionView::TestCase
  include AnalyzeHelper

  test "renders a pill badge for every supported sentiment" do
    Feedback::SENTIMENT_VALUES.each do |sentiment|
      badge = sentiment_badge(sentiment)
      assert badge.present?, "expected a badge for #{sentiment}"
      assert_includes badge, "badge rounded-pill"
      assert_includes badge, sentiment.capitalize
    end
  end

  test "gives excited a solid fill and the rest subtle ones" do
    assert_includes sentiment_badge("excited"), "text-bg-success"
    assert_includes sentiment_badge("positive"), "bg-success-subtle"
    assert_includes sentiment_badge("negative"), "bg-danger-subtle"
  end

  test "renders nothing when sentiment is missing or unrecognised" do
    assert_nil sentiment_badge(nil)
    assert_nil sentiment_badge("")
    assert_nil sentiment_badge("elated")
  end

  test "interview_tag_link labels the interview by its position and links to its anchored, range-widened URL" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi", created_at: Time.zone.parse("2026-07-01 10:00"))
    interview_numbers = { feedback.id => 3 }

    html = interview_tag_link(loop_record, feedback, interview_numbers)

    assert_match(/Interview #3/, html)
    assert_match("range=custom", html)
    assert_match("from=2026-07-01", html)
    assert_match("to=2026-07-01", html)
    assert_match("#feedback-#{feedback.id}", html)
    assert_match("tab=per_loop", html)
  end

  test "group_quotes_by_interview collapses repeated quotes from the same interview into one group" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    older = loop_record.feedbacks.create!(transcript: "a", created_at: 2.days.ago)
    newer = loop_record.feedbacks.create!(transcript: "b", created_at: 1.day.ago)
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 2)
    theme = insight.themes.create!(title: "T", mention_count: 2, sentiment: "positive")
    quote_a1 = theme.quotes.create!(feedback: newer, text: "first from newer")
    quote_a2 = theme.quotes.create!(feedback: newer, text: "second from newer")
    quote_b = theme.quotes.create!(feedback: older, text: "from older")
    interview_numbers = { older.id => 1, newer.id => 2 }

    groups = group_quotes_by_interview(theme.quotes, interview_numbers)

    assert_equal [older, newer], (groups.map { |g| g[:feedback] })
    assert_equal [quote_b], groups[0][:quotes]
    assert_equal [quote_a1, quote_a2], groups[1][:quotes]
  end

  test "canonical_topic_for finds the theme/feature request whose quote matches a raw extracted point verbatim" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    theme = insight.themes.create!(title: "Onboarding", mention_count: 1, sentiment: "positive")
    theme.quotes.create!(feedback: feedback, text: "it was quick")

    assert_equal theme, canonical_topic_for(feedback, "it was quick")
    assert_nil canonical_topic_for(feedback, "no such quote was ever clustered")
  end
end
