class CreateInsights < ActiveRecord::Migration[8.1]
  def change
    create_table :insights do |t|
      t.text :summary
      t.string :sentiment
      t.references :loop, null: false, foreign_key: true

      t.timestamps
    end
  end
end
