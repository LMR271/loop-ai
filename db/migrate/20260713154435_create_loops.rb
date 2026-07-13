class CreateLoops < ActiveRecord::Migration[8.1]
  def change
    create_table :loops do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.integer :status, default: 0
      t.string :slug
      t.string :logo_url

      t.timestamps
    end
    add_index :loops, :slug, unique: true
  end
end
