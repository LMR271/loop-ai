class FinalizeTeamOrganization < ActiveRecord::Migration[8.1]
  def change
    remove_index :teams, name: "index_teams_on_account_owner_id_and_email"
    remove_reference :teams, :account_owner, foreign_key: { to_table: :users }

    change_column_null :teams, :organization_id, false
    add_index :teams, [:organization_id, :email], unique: true
  end
end
