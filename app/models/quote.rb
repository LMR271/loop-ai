class Quote < ApplicationRecord
  belongs_to :quotable, polymorphic: true
  belongs_to :feedback
end
