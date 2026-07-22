require "test_helper"

class FeedbackAnalyzerTest < ActiveSupport::TestCase
  Stub = Struct.new(:payload) { def complete(**) = payload }

  test "writes extracted points and preserves the existing title and summary" do
    founder = User.create!(email: "founder1@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder, organization: founder.owned_organization)
    feedback = Feedback.create!(loop: loop_record, transcript: "I felt overwhelmed", title: "From EL", summary: "EL summary")
    payload = { "points" => [{ "kind" => "request", "title" => "Guided walkthrough", "quote" => "a run-through agent would help" }] }

    FeedbackAnalyzer.new(feedback, client: Stub.new(payload)).call

    feedback.reload
    assert_equal "a run-through agent would help", feedback.extracted_points["points"].first["quote"]
    assert_equal "From EL", feedback.title
    assert_equal "EL summary", feedback.summary
  end

  test "degrades gracefully when the LLM fails" do
    founder = User.create!(email: "founder2@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder, organization: founder.owned_organization)
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    failing = Object.new
    def failing.complete(**) = raise(LlmClient::Error, "boom")

    FeedbackAnalyzer.new(feedback, client: failing).call

    assert_equal({}, feedback.reload.extracted_points)
  end
end
