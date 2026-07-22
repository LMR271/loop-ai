class RemoveNotificationsSeenAtFromLoops < ActiveRecord::Migration[8.1]
  def change
    # Superseded by the per-user LoopView#last_seen_feedback_count (see
    # CreateLoopViews) — the navbar bell now tracks read state per teammate,
    # not workspace-wide, so this column never got real use.
    remove_column :loops, :notifications_seen_at, :datetime
  end
end
