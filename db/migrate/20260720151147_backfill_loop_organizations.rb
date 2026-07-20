class BackfillLoopOrganizations < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE loops SET organization_id = organizations.id
      FROM organizations
      WHERE organizations.owner_id = loops.user_id
    SQL
  end

  def down
    execute "UPDATE loops SET organization_id = NULL"
  end
end
