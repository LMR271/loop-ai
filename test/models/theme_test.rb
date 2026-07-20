require "test_helper"

class ThemeTest < ActiveSupport::TestCase
  test "theme has quotes and belongs to insight" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    insight = loop_record.create_insight!
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    theme = insight.themes.create!(title: "Onboarding", mention_count: 1)
    quote = theme.quotes.create!(feedback: feedback, text: "quote text")

    assert_equal insight, theme.insight
    assert_equal [quote], theme.quotes.to_a
  end
end
