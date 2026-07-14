class Question < ApplicationRecord
  belongs_to :loop

  validates :body, presence: true
end
