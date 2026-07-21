class AddUniqueIndexToInsightsLoopId < ActiveRecord::Migration[8.1]
  def change
    remove_index :insights, :loop_id if index_exists?(:insights, :loop_id)
    add_index :insights, :loop_id, unique: true
  end
end
