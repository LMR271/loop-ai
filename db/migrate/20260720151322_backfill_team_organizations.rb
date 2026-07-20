class BackfillTeamOrganizations < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE teams SET organization_id = organizations.id
      FROM organizations
      WHERE organizations.owner_id = teams.account_owner_id
    SQL
  end

  def down
    execute "UPDATE teams SET organization_id = NULL"
  end
end
