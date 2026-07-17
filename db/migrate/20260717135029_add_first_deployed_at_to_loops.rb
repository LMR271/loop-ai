class AddFirstDeployedAtToLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :loops, :first_deployed_at, :datetime
  end
end
