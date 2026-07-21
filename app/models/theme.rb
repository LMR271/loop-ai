class Theme < ApplicationRecord
  belongs_to :insight
  has_many :quotes, as: :quotable, dependent: :destroy
end
