class RenameMembershipsToTeams < ActiveRecord::Migration[8.1]
  def change
    rename_table :memberships, :teams
  end
end
