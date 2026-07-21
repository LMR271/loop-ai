require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "stores analysis columns" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user)
    feedback = Feedback.create!(
      loop: loop_record, transcript: "hi",
      title: "First week", summary: "Felt overwhelmed",
      extracted_points: { "points" => [{ "kind" => "theme", "title" => "Onboarding", "quote" => "too many features" }] }
    )
    assert_equal "First week", feedback.reload.title
    assert_equal "too many features", feedback.extracted_points["points"].first["quote"]
  end
end
