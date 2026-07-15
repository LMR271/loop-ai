class AddDashboardStatKeysToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :dashboard_stat_keys, :jsonb, default: [], null: false
  end
end
