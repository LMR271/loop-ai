require "test_helper"

class ElevenLabsWebhooksControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET = "wsec_testsecret"

  setup do
    @previous_secret = ENV["ELEVENLABS_WEBHOOK_SECRET"]
    ENV["ELEVENLABS_WEBHOOK_SECRET"] = SECRET
    @user = User.create!(email: "webhook-test@example.com", password: "password123")
    @loop = @user.loops.create!(name: "Webhook Test Loop", agent_id: "agent_webhook_test", status: :active)
  end

  teardown { ENV["ELEVENLABS_WEBHOOK_SECRET"] = @previous_secret }

  def payload(agent_id: "agent_webhook_test", conversation_id: "conv_abc", sentiment: "excited")
    {
      type: "post_call_transcription",
      data: {
        agent_id: agent_id,
        conversation_id: conversation_id,
        transcript: [
          { role: "agent", message: "How was it?" },
          { role: "user", message: "Brilliant, honestly." }
        ],
        analysis: { data_collection_results: {
          sentiment: { value: sentiment, rationale: "They said brilliant." }
        } }
      }
    }.to_json
  end

  def post_webhook(body, secret: SECRET, timestamp: Time.current.to_i)
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    post eleven_labs_webhook_path, params: body,
         headers: { "ElevenLabs-Signature" => "t=#{timestamp},v0=#{digest}",
                    "Content-Type" => "application/json" }
  end

  test "records a feedback with transcript and sentiment on the matching loop" do
    assert_difference "Feedback.count", 1 do
      post_webhook(payload)
    end
    assert_response :ok

    feedback = Feedback.last
    assert_equal @loop, feedback.loop
    assert_equal "excited", feedback.sentiment
    assert_equal "They said brilliant.", feedback.sentiment_rationale
    assert_equal "conv_abc", feedback.conversation_id
    assert_equal "Agent: How was it?\nRespondent: Brilliant, honestly.", feedback.transcript
  end

  test "enqueues analysis for a newly recorded feedback" do
    assert_enqueued_with(job: AnalyzeFeedbackJob) do
      post_webhook(payload)
    end
    assert_response :ok
  end

  test "rejects an invalid signature and writes nothing" do
    assert_no_difference "Feedback.count" do
      post_webhook(payload, secret: "wsec_wrong")
    end
    assert_response :unauthorized
  end

  # A 404 here would count toward the 10 failures that disable the workspace webhook,
  # killing ingestion for every loop.
  test "returns ok without recording when the agent is unknown" do
    assert_no_difference "Feedback.count" do
      post_webhook(payload(agent_id: "agent_does_not_exist"))
    end
    assert_response :ok
  end

  test "is idempotent on conversation_id" do
    post_webhook(payload)
    assert_response :ok

    assert_no_difference "Feedback.count" do
      post_webhook(payload)
    end
    assert_response :ok
  end

  test "ignores non-transcription events" do
    body = { type: "post_call_audio", data: { agent_id: "agent_webhook_test" } }.to_json
    assert_no_difference "Feedback.count" do
      post_webhook(body)
    end
    assert_response :ok
  end
end
