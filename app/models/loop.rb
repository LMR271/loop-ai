class Loop < ApplicationRecord
  has_secure_token :slug

  belongs_to :user
  has_one :insight
  has_many :questions
  has_many :feedbacks
end
