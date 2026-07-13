class Loop < ApplicationRecord
  belongs_to :user
  has_one :insight
end
