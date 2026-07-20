class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.references :insight, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :mention_count, default: 0, null: false
      t.string :sentiment
      t.timestamps
    end
  end
end
