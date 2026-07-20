class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :quotable, polymorphic: true, null: false
      t.references :feedback, null: false, foreign_key: true
      t.text :text
      t.timestamps
    end
  end
end
