class BackfillOrganizations < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO organizations (name, owner_id, created_at, updated_at)
      SELECT organization_name, id, NOW(), NOW() FROM users
    SQL
  end

  def down
    execute "DELETE FROM organizations"
  end
end
