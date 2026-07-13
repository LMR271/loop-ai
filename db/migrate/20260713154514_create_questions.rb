class CreateQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :questions do |t|
      t.references :loop, null: false, foreign_key: true
      t.text :body
      t.integer :position

      t.timestamps
    end
  end
end
