class LoopView < ApplicationRecord
  belongs_to :user
  belongs_to :loop

  validates :user_id, uniqueness: { scope: :loop_id }
end
