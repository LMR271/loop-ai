class LoopView < ApplicationRecord
  belongs_to :user
  belongs_to :loop

  validates :user_id, uniqueness: { scope: :loop_id }

  def self.stamp!(user:, loop:)
    loop_view = user.loop_views.find_or_initialize_by(loop: loop)
    count = loop.feedbacks.size
    loop_view.update!(last_seen_feedback_count: count) if count > loop_view.last_seen_feedback_count.to_i
  end
end
