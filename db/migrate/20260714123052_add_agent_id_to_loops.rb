class AddAgentIdToLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :loops, :agent_id, :string
  end
end
