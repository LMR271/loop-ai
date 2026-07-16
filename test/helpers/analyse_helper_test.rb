require "test_helper"

class AnalyseHelperTest < ActionView::TestCase
  include AnalyseHelper

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
end
