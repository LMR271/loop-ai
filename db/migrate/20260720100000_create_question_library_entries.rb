class CreateQuestionLibraryEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :question_library_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.string :category, null: false
      t.text :content, null: false
      t.integer :times_used, null: false, default: 0

      t.timestamps
    end

    add_index :question_library_entries, [:user_id, :category]
  end
end
