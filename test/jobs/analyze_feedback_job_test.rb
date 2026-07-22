require "test_helper"

class AnalyzeFeedbackJobTest < ActiveJob::TestCase
  test "runs FeedbackAnalyzer for the feedback" do
    user = User.create!(email: "analyze-job-test@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user, organization: user.owned_organization)
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    called = nil
    stub_instance_method(FeedbackAnalyzer, :call, -> { called = true }) do
      AnalyzeFeedbackJob.perform_now(feedback)
    end
    assert called
  end
end
