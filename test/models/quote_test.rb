require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  test "quote bridges a theme to the feedback it came from" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder, organization: founder.owned_organization)
    insight = loop_record.create_insight!
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    theme = insight.themes.create!(title: "Onboarding", mention_count: 1)
    quote = theme.quotes.create!(feedback: feedback, text: "too many features")

    assert_equal theme, quote.quotable
    assert_equal [quote], feedback.quotes.to_a
  end
end
