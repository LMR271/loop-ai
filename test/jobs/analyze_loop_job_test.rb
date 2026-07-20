require "test_helper"

class AnalyzeLoopJobTest < ActiveJob::TestCase
  test "analyzes then writes the insight" do
    founder = User.create!(email: "founder3@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    Feedback.create!(loop: loop_record, transcript: "hi",
                     extracted_points: { "points" => [{ "kind" => "theme", "title" => "T", "quote" => "q" }] })
    result = { "overall_sentiment" => "neutral", "summary" => "s", "themes" => [], "feature_requests" => [] }

    stub_instance_method(LoopAnalyzer, :call, -> { result }) do
      AnalyzeLoopJob.perform_now(loop_record)
    end

    assert_equal "s", loop_record.reload.insight.summary
  end
end
