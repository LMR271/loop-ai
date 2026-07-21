class Insight < ApplicationRecord
  belongs_to :loop
  has_many :themes, dependent: :destroy
  has_many :feature_requests, dependent: :destroy
end
