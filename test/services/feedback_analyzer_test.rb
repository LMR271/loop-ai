require "test_helper"

class FeedbackAnalyzerTest < ActiveSupport::TestCase
  Stub = Struct.new(:payload) { def complete(**) = payload }

  test "writes title, summary, and extracted points onto the feedback" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    feedback = Feedback.create!(loop: loop_record, transcript: "I felt overwhelmed by the features")
    payload = {
      "title" => "First week", "summary" => "Overwhelmed but hopeful",
      "points" => [{ "kind" => "request", "title" => "Guided walkthrough", "quote" => "a run-through agent would help" }]
    }

    FeedbackAnalyzer.new(feedback, client: Stub.new(payload)).call

    assert_equal "First week", feedback.reload.title
    assert_equal "a run-through agent would help", feedback.extracted_points["points"].first["quote"]
  end

  test "degrades gracefully when the LLM fails" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    failing = Object.new
    def failing.complete(**) = raise(LlmClient::Error, "boom")

    FeedbackAnalyzer.new(feedback, client: failing).call

    assert_nil feedback.reload.title
    assert_equal({}, feedback.extracted_points)
  end
end
