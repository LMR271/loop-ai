class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name
      t.references :owner, null: false, foreign_key: { to_table: :users }, index: { unique: true }

      t.timestamps
    end
  end
end
