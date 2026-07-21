# Wraps an inbound post-call webhook body and exposes only what a Feedback needs.
# All knowledge of ElevenLabs' (undocumented) payload shape lives here, so the
# controller never digs through nested hashes.
class ElevenLabsWebhookPayload
  TRANSCRIPTION_TYPE = "post_call_transcription"
  SENTIMENT_FIELD = "sentiment"

  def initialize(raw_body)
    @body = JSON.parse(raw_body.to_s)
  rescue JSON::ParserError
    @body = {}
  end

  # Audio events (post_call_audio) share this endpoint; only transcriptions carry a transcript.
  def transcription?
    @body["type"] == TRANSCRIPTION_TYPE
  end

  def agent_id
    data["agent_id"]
  end

  def conversation_id
    data["conversation_id"]
  end

  def transcript
    TranscriptFormatter.new(data["transcript"]).call
  end

  def sentiment
    sentiment_result["value"]
  end

  def sentiment_rationale
    sentiment_result["rationale"]
  end

  def summary_title
    analysis["call_summary_title"]
  end

  def transcript_summary
    analysis["transcript_summary"]
  end

  private

  def data
    @body["data"] || {}
  end

  def analysis
    data["analysis"] || {}
  end

  # Both shapes arrive in every real payload. Prefer the hash; fall back to the list;
  # degrade to {} so an unexpected shape yields nil columns rather than raising —
  # a 500 here risks the workspace-wide webhook being disabled.
  def sentiment_result
    @sentiment_result ||= hash_form || list_form || {}
  end

  def hash_form
    analysis.dig("data_collection_results", SENTIMENT_FIELD)
  end

  def list_form
    Array(analysis["data_collection_results_list"])
      .find { |entry| entry["data_collection_id"] == SENTIMENT_FIELD }
  end
end
