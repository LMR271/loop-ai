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
  end
end
