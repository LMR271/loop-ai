# Flattens ElevenLabs' transcript (an array of turn objects) into the plain-text
# "Agent:"/"Respondent:" form db/seeds.rb already uses, so real and seeded feedback
# render identically on the Analyze dashboard.
class TranscriptFormatter
  ROLE_LABELS = { "agent" => "Agent", "user" => "Respondent" }.freeze

  def initialize(turns)
    @turns = turns
  end

  def call
    Array(@turns).filter_map { |turn| format_turn(turn) }.join("\n")
  end

  private

  # Turns without a message (tool calls, for instance) carry nothing worth reading.
  def format_turn(turn)
    message = turn["message"].presence
    return if message.blank?

    "#{label_for(turn['role'])}: #{message}"
  end

  def label_for(role)
    ROLE_LABELS.fetch(role) { role.to_s.capitalize.presence || "Unknown" }
  end
end
