# app/services/eleven_labs_agent_creator.rb
class ElevenLabsAgentCreator
  class Error < StandardError; end

  URL = "https://api.elevenlabs.io/v1/convai/agents/create"
  TIMEOUT = 15 # seconds

  def initialize(loop)
    @loop = loop
  end

  def call
    extract_agent_id(post)
  rescue RestClient::Exception => e
    raise Error, "ElevenLabs returned #{e.http_code}: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED, RestClient::Exceptions::Timeout => e
    raise Error, "Could not reach ElevenLabs (#{e.message})"
  rescue JSON::ParserError
    raise Error, "ElevenLabs returned an unreadable response"
  end

  private

  def post
    RestClient::Request.execute(
      method: :post,
      url: URL,
      payload: request_body.to_json,
      headers: headers,
      timeout: TIMEOUT,
      open_timeout: TIMEOUT
    )
  end

  def extract_agent_id(response)
    agent_id = JSON.parse(response.body)["agent_id"]
    agent_id.presence || raise(Error, "ElevenLabs response did not include an agent_id")
  end

  def request_body
    { name: @loop.name, conversation_config: conversation_config, platform_settings: platform_settings }
  end

  # Tells ElevenLabs' analysis LLM to score each finished conversation. The result
  # comes back in the post-call webhook under analysis.data_collection_results,
  # so this must be set at creation time — existing agents won't have it.
  def platform_settings
    { data_collection: { sentiment: { type: "string", description: sentiment_description } } }
  end

  def sentiment_description
    <<~DESCRIPTION.squish
      Classify how the RESPONDENT (not the agent) felt overall during this conversation.
      Answer with exactly one word from this list: #{Feedback::SENTIMENT_VALUES.join(', ')}.
      Use "excited" only for clear enthusiasm, such as volunteering extra ideas or using
      strong positive language; use "positive" for satisfied but measured.
      Use "frustrated" for irritation with a specific problem, "negative" for broader dislike.
      Use "neutral" when the respondent is brief, hard to read, or gives no emotional signal.
    DESCRIPTION
  end

  def conversation_config
    {
      agent: { prompt: { prompt: SystemPromptBuilder.new(@loop).call, llm: "qwen35-397b-a17b" } },
      tts: { voice_id: "ePn9OncKq8KyJvrTRqTi" } # a default ElevenLabs voice
    }
  end

  def headers
    {
      "xi-api-key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  def api_key
    ENV.fetch("ELEVENLABS_API_KEY", nil).presence || raise(Error, "ELEVENLABS_API_KEY is not set")
  end
end
