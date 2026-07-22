require "test_helper"

class LoopTest < ActiveSupport::TestCase
  test "unanalyzed_feedback_count counts interviews since the last analysis" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user, organization: user.owned_organization)
    3.times { Feedback.create!(loop: loop_record, transcript: "hi") }
    loop_record.create_insight!(analyzed_feedback_count: 1)
    assert_equal 2, loop_record.unanalyzed_feedback_count
  end

  test "unseen_feedback_count counts all feedback when never marked seen" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }

    assert_equal 2, loop_record.unseen_feedback_count
  end

  test "mark_notifications_seen! resets unseen_feedback_count until new feedback arrives" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")

    loop_record.mark_notifications_seen!
    assert_equal 0, loop_record.unseen_feedback_count

    Feedback.create!(loop: loop_record, transcript: "hi again")
    assert_equal 1, loop_record.unseen_feedback_count
  test "feedbacks_pending_extraction returns only feedbacks without extracted points" do
    founder = User.create!(email: "pend@example.com", password: "password123")
    loop_record = Loop.create!(name: "Pending", user: founder, organization: founder.owned_organization)
    points = { "points" => [{ "kind" => "theme", "title" => "t", "quote" => "q" }] }
    analyzed = Feedback.create!(loop: loop_record, transcript: "a", extracted_points: points)
    pending = Feedback.create!(loop: loop_record, transcript: "b")

    assert_includes loop_record.feedbacks_pending_extraction, pending
    assert_not_includes loop_record.feedbacks_pending_extraction, analyzed
    assert_equal 1, loop_record.pending_extraction_count
  end
end
