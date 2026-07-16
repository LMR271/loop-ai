class Feedback < ApplicationRecord
  # The vocabulary ElevenLabs' analysis LLM is asked to answer with. Lives here rather
  # than on the creator service: it describes feedback data, and both the prompt that
  # requests it and the validation that accepts it must agree.
  SENTIMENT_VALUES = %w[excited positive neutral frustrated negative].freeze

  belongs_to :loop

  # nil is valid: agents provisioned before data_collection existed return no sentiment,
  # and the extractor degrades to nil rather than raising on an unexpected payload shape.
  validates :sentiment, inclusion: { in: SENTIMENT_VALUES }, allow_nil: true
end
