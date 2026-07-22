class LlmClient
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5-mini")
  REASONING_EFFORT = ENV.fetch("OPENAI_REASONING_EFFORT", "low")

  class Error < StandardError; end

  def initialize(client: OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil)))
    @client = client
  end

  # Returns a Hash parsed from the model's JSON output, validated against `schema`.
  def complete(system:, user:, schema:)
    response = @client.chat(parameters: body(system, user, schema))
    extract(response)
  rescue StandardError => e
    raise Error, "OpenAI request failed: #{e.message}"
  end

  private

  def body(system, user, schema)
    {
      model: MODEL,
      reasoning_effort: REASONING_EFFORT,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
      response_format: { type: "json_schema", json_schema: { name: "analysis", schema: schema, strict: true } }
    }
  end

  def extract(response)
    raise Error, response.dig("error", "message") if response["error"]

    JSON.parse(response.dig("choices", 0, "message", "content"))
  end
end
