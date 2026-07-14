class Loop < ApplicationRecord
  belongs_to :user
  enum :status, { draft: 0, active: 1, closed: 2 }
  has_many :feedbacks, dependent: :destroy
  has_one :insight, dependent: :destroy
  has_many :questions, dependent: :destroy
end
