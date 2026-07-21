require "test_helper"

class ElevenLabsWebhookPayloadTest < ActiveSupport::TestCase
  def real_payload
    ElevenLabsWebhookPayload.new(file_fixture("elevenlabs_post_call_transcription.json").read)
  end

  test "reads ids and type from the real captured payload" do
    payload = real_payload
    assert payload.transcription?
    assert_equal "agent_3901kxnnfb2tfe6vbq806fj6wf3j", payload.agent_id
    assert_equal "conv_4501kxnnh95ef2189cmtnj8051zh", payload.conversation_id
  end

  test "extracts sentiment and rationale from the real captured payload" do
    payload = real_payload
    assert_equal "neutral", payload.sentiment
    assert_includes payload.sentiment_rationale, "constructive suggestion"
  end

  test "flattens the real transcript into Agent/Respondent lines" do
    transcript = real_payload.transcript
    assert_includes transcript, "Agent: Hello, and thank you for taking the time"
    assert_includes transcript, "Respondent: Hey."
    refute_includes transcript, "user:"
  end

  test "falls back to the list form when the hash form is absent" do
    body = {
      "type" => "post_call_transcription",
      "data" => { "analysis" => { "data_collection_results_list" => [
        { "data_collection_id" => "sentiment", "value" => "excited", "rationale" => "because" }
      ] } }
    }.to_json

    payload = ElevenLabsWebhookPayload.new(body)
    assert_equal "excited", payload.sentiment
    assert_equal "because", payload.sentiment_rationale
  end

  test "degrades to nil rather than raising on an unexpected shape" do
    payload = ElevenLabsWebhookPayload.new({ "type" => "post_call_transcription" }.to_json)
    assert_nil payload.sentiment
    assert_nil payload.sentiment_rationale
    assert_nil payload.agent_id
    assert_equal "", payload.transcript
  end

  test "degrades to nil rather than raising on unparseable json" do
    payload = ElevenLabsWebhookPayload.new("not json at all")
    refute payload.transcription?
    assert_nil payload.sentiment
  end

  test "identifies non-transcription events" do
    refute ElevenLabsWebhookPayload.new({ "type" => "post_call_audio" }.to_json).transcription?
  end

  test "exposes the summary title and transcript summary from analysis" do
    raw = file_fixture("elevenlabs_post_call_transcription.json").read
    payload = ElevenLabsWebhookPayload.new(raw)

    assert_equal "Onboarding Feedback", payload.summary_title
    assert payload.transcript_summary.to_s.start_with?("The user provided feedback")
  end

  test "title and summary degrade to nil on a malformed body" do
    payload = ElevenLabsWebhookPayload.new("not json")

    assert_nil payload.summary_title
    assert_nil payload.transcript_summary
  end
end
