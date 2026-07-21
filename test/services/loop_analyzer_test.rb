require "test_helper"

class LoopAnalyzerTest < ActiveSupport::TestCase
  CaptureStub = Struct.new(:payload) do
    attr_reader :user_arg
    def complete(system:, user:, schema:)
      @user_arg = user
      payload
    end
  end

  test "feeds tagged extracted points to the LLM and returns its result" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: user)
    fb = Feedback.create!(loop: loop_record, transcript: "hi",
                          extracted_points: { "points" => [{ "kind" => "theme", "title" => "Onboarding", "quote" => "too many features" }] })
    stub = CaptureStub.new({ "overall_sentiment" => "neutral", "summary" => "ok", "themes" => [], "feature_requests" => [] })

    result = LoopAnalyzer.new(loop_record, client: stub).call

    assert_equal "neutral", result["overall_sentiment"]
    assert_includes stub.user_arg, fb.id.to_s   # points were tagged with the feedback id
  end
end
