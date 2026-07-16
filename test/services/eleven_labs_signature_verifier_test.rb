require "test_helper"

class ElevenLabsSignatureVerifierTest < ActiveSupport::TestCase
  SECRET = "wsec_testsecret"

  def header_for(body, timestamp: Time.current.to_i, secret: SECRET)
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{body}")
    "t=#{timestamp},v0=#{digest}"
  end

  test "accepts a correctly signed body" do
    body = '{"hello":"world"}'
    assert ElevenLabsSignatureVerifier.new(header_for(body), body, SECRET).valid?
  end

  test "rejects a tampered body" do
    header = header_for('{"hello":"world"}')
    refute ElevenLabsSignatureVerifier.new(header, '{"hello":"tampered"}', SECRET).valid?
  end

  test "rejects a signature made with a different secret" do
    body = '{"hello":"world"}'
    header = header_for(body, secret: "wsec_wrong")
    refute ElevenLabsSignatureVerifier.new(header, body, SECRET).valid?
  end

  test "rejects a stale timestamp even when the digest matches" do
    body = '{"hello":"world"}'
    header = header_for(body, timestamp: 31.minutes.ago.to_i)
    refute ElevenLabsSignatureVerifier.new(header, body, SECRET).valid?
  end

  test "rejects blank, malformed, and secretless input" do
    body = '{"hello":"world"}'
    refute ElevenLabsSignatureVerifier.new(nil, body, SECRET).valid?
    refute ElevenLabsSignatureVerifier.new("garbage", body, SECRET).valid?
    refute ElevenLabsSignatureVerifier.new("t=123", body, SECRET).valid?
    refute ElevenLabsSignatureVerifier.new(header_for(body), body, nil).valid?
  end

  test "verifies the real captured payload" do
    body = file_fixture("elevenlabs_post_call_transcription.json").read
    assert ElevenLabsSignatureVerifier.new(header_for(body), body, SECRET).valid?
  end
end
