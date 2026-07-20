class LoopAnalyzer
  SYSTEM = <<~PROMPT.freeze
    You cluster structured points extracted from many user interviews in one feedback loop.
    Input is a JSON list of points, each tagged with the `feedback_id` it came from.
    GROUP related points — do not re-summarize away the detail. Produce:
    - `overall_sentiment`: one of excited, positive, neutral, frustrated, negative.
    - `summary`: a narrative of where the product is going across all interviews.
    - `themes`: recurring patterns (include friction/pain points). Each has a title,
      one-line description, `mention_count` (how many interviews expressed it), a
      sentiment, and `citations` (feedback_id + the VERBATIM quote that supports it).
    - `feature_requests`: specific things users asked for, same citation shape.
    Every quote must be copied verbatim from the input points, never invented.
  PROMPT

  CITATIONS = {
    type: "array",
    items: {
      type: "object", additionalProperties: false, required: %w[feedback_id quote],
      properties: { feedback_id: { type: "integer" }, quote: { type: "string" } }
    }
  }.freeze

  SCHEMA = {
    type: "object", additionalProperties: false,
    required: %w[overall_sentiment summary themes feature_requests],
    properties: {
      overall_sentiment: { type: "string", enum: Feedback::SENTIMENT_VALUES },
      summary: { type: "string" },
      themes: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[title description mention_count sentiment citations],
          properties: {
            title: { type: "string" }, description: { type: "string" },
            mention_count: { type: "integer" },
            sentiment: { type: "string", enum: Feedback::SENTIMENT_VALUES },
            citations: CITATIONS
          }
        }
      },
      feature_requests: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[title description citations],
          properties: { title: { type: "string" }, description: { type: "string" }, citations: CITATIONS }
        }
      }
    }
  }.freeze

  def initialize(loop_record, client: LlmClient.new)
    @loop = loop_record
    @client = client
  end

  def call
    @client.complete(system: SYSTEM, user: collect_points.to_json, schema: SCHEMA)
  end

  def analyzed_count
    @loop.feedbacks.where.not(extracted_points: {}).count
  end

  private

  def collect_points
    @loop.feedbacks.where.not(extracted_points: {}).flat_map do |feedback|
      Array(feedback.extracted_points["points"]).map { |point| point.merge("feedback_id" => feedback.id) }
    end
  end
end
