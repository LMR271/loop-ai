class AddNotificationsSeenAtToLoops < ActiveRecord::Migration[8.1]
  def up
    add_column :loops, :notifications_seen_at, :datetime

    # Without this, every loop with historical feedback would show up as a
    # brand-new unseen notification the moment this ships, since a nil
    # notifications_seen_at means "count all feedback as unseen."
    execute "UPDATE loops SET notifications_seen_at = NOW()"
  end

  def down
    remove_column :loops, :notifications_seen_at
  end
end
