class AddOrganizationNameToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :organization_name, :string
  end
end
