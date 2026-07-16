# Verifies the "ElevenLabs-Signature" header on an inbound post-call webhook.
#
# Format and construction are undocumented; both were confirmed against a real payload:
#   header:    t=<unix_ts>,v0=<sha256_hex>
#   signature: HMAC-SHA256(secret, "<t>.<raw_body>")
#
# The body must be the RAW request bytes — reparsing the JSON changes them and the
# hash no longer matches.
class ElevenLabsSignatureVerifier
  TOLERANCE = 30.minutes

  def initialize(header, raw_body, secret = ENV.fetch("ELEVENLABS_WEBHOOK_SECRET", nil))
    @header = header
    @raw_body = raw_body
    @secret = secret
  end

  def valid?
    return false if @secret.blank? || @header.blank?

    timestamp, signature = parts.values_at("t", "v0")
    return false if timestamp.blank? || signature.blank? || stale?(timestamp)

    ActiveSupport::SecurityUtils.secure_compare(expected(timestamp), signature)
  end

  private

  def parts
    @header.to_s.split(",").each_with_object({}) do |part, acc|
      key, value = part.split("=", 2)
      acc[key.to_s.strip] = value
    end
  end

  # Blunts replay of a captured payload: a signature stays valid forever otherwise.
  def stale?(timestamp)
    Time.zone.at(timestamp.to_i) < TOLERANCE.ago
  end

  def expected(timestamp)
    OpenSSL::HMAC.hexdigest("SHA256", @secret, "#{timestamp}.#{@raw_body}")
  end
end
