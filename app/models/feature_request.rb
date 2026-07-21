class FeatureRequest < ApplicationRecord
  belongs_to :insight
  has_many :quotes, as: :quotable, dependent: :destroy

  enum :status, { open: 0, planned: 1, done: 2, dismissed: 3 }
end
