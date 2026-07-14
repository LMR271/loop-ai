class Loop < ApplicationRecord
  enum :status, { draft: 0, on_air: 1 }
  belongs_to :user
  has_one :insight, dependent: :destroy
  has_many :questions, dependent: :destroy
  has_many :feedbacks, dependent: :destroy

  accepts_nested_attributes_for :questions, allow_destroy: true
end
