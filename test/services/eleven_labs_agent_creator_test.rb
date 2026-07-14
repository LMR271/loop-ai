require "test_helper"

class ElevenLabsAgentCreatorTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "svc@example.com", password: "password123")
    @loop = user.loops.create!(name: "Research", description: "Understand onboarding")
    @loop.questions.create!(body: "What worked?", position: 1)
  end

  test "returns the agent_id from a successful response" do
    response = Struct.new(:body).new({ "agent_id" => "agent_123" }.to_json)

    with_api_key("secret") do
      stub_instance_method(ElevenLabsAgentCreator, :post, ->(*) { response }) do
        assert_equal "agent_123", ElevenLabsAgentCreator.new(@loop).call
      end
    end
  end

  test "raises a domain error when the API key is missing" do
    with_api_key(nil) do
      error = assert_raises(ElevenLabsAgentCreator::Error) do
        ElevenLabsAgentCreator.new(@loop).call
      end

      assert_match(/ELEVENLABS_API_KEY/, error.message)
    end
  end

  test "raises a domain error when the response has no agent_id" do
    response = Struct.new(:body).new({}.to_json)

    with_api_key("secret") do
      stub_instance_method(ElevenLabsAgentCreator, :post, ->(*) { response }) do
        assert_raises(ElevenLabsAgentCreator::Error) do
          ElevenLabsAgentCreator.new(@loop).call
        end
      end
    end
  end

  test "wraps a RestClient failure in a domain error" do
    raising = ->(*) { raise RestClient::Exceptions::Timeout.new("timed out") }

    with_api_key("secret") do
      stub_instance_method(ElevenLabsAgentCreator, :post, raising) do
        assert_raises(ElevenLabsAgentCreator::Error) do
          ElevenLabsAgentCreator.new(@loop).call
        end
      end
    end
  end

  private

  def with_api_key(value)
    original = ENV["ELEVENLABS_API_KEY"]
    ENV["ELEVENLABS_API_KEY"] = value
    yield
  ensure
    ENV["ELEVENLABS_API_KEY"] = original
  end
end
