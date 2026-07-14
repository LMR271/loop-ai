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
    { name: @loop.name, conversation_config: conversation_config }
  end

  def conversation_config
    {
      agent: { prompt: { prompt: SystemPromptBuilder.new(@loop).call, llm: "gemini-2.0-flash" } },
      tts: { voice_id: "JBFqnCBsd6RMkjVDRZzb" } # a default ElevenLabs voice
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
