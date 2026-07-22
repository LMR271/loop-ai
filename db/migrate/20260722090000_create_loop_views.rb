class CreateLoopViews < ActiveRecord::Migration[8.1]
  def change
    create_table :loop_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :loop, null: false, foreign_key: true
      t.integer :last_seen_feedback_count, null: false, default: 0

      t.timestamps
    end

    add_index :loop_views, %i[user_id loop_id], unique: true
  end
end
