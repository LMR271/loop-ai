class FeedbackAnalyzer
  SYSTEM = <<~PROMPT.freeze
    You analyze a single user feedback interview transcript.
    Return `points`, a list of the specific themes and feature requests the respondent
    raised. For every point, copy a `quote` VERBATIM from the transcript — never paraphrase.
    `kind` is "theme" or "request".
  PROMPT

  SCHEMA = {
    type: "object", additionalProperties: false, required: %w[points],
    properties: {
      points: {
        type: "array",
        items: {
          type: "object", additionalProperties: false, required: %w[kind title quote],
          properties: {
            kind: { type: "string", enum: %w[theme request] },
            title: { type: "string" },
            quote: { type: "string" }
          }
        }
      }
    }
  }.freeze

  def initialize(feedback, client: LlmClient.new)
    @feedback = feedback
    @client = client
  end

  def call
    result = @client.complete(system: SYSTEM, user: @feedback.transcript.to_s, schema: SCHEMA)
    @feedback.update!(extracted_points: { "points" => result["points"] })
  rescue LlmClient::Error => e
    Rails.logger.warn("[FeedbackAnalyzer] feedback=#{@feedback.id} failed: #{e.message}")
  end
end
