require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  class FakeOpenAI
    def initialize(response) = @response = response
    def chat(parameters:) = @response
  end

  test "parses the JSON content from a chat response" do
    body = { "choices" => [{ "message" => { "content" => '{"title":"ok"}' } }] }
    result = LlmClient.new(client: FakeOpenAI.new(body)).complete(system: "s", user: "u", schema: {})
    assert_equal "ok", result["title"]
  end

  test "raises Error when the response carries an error" do
    client = LlmClient.new(client: FakeOpenAI.new({ "error" => { "message" => "boom" } }))
    assert_raises(LlmClient::Error) { client.complete(system: "s", user: "u", schema: {}) }
  end
end
