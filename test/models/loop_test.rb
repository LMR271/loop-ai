require "test_helper"

class LoopTest < ActiveSupport::TestCase
  test "unanalyzed_feedback_count counts interviews since the last analysis" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user)
    3.times { Feedback.create!(loop: loop_record, transcript: "hi") }
    loop_record.create_insight!(analyzed_feedback_count: 1)
    assert_equal 2, loop_record.unanalyzed_feedback_count
  end
end
