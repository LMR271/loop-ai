class FinalizeLoopOrganization < ActiveRecord::Migration[8.1]
  def change
    change_column_null :loops, :organization_id, false
    change_column_null :loops, :user_id, true
  end
end
