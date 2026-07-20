class AddOrganizationToTeams < ActiveRecord::Migration[8.1]
  def change
    add_reference :teams, :organization, null: true, foreign_key: true
  end
end
