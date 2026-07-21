class CreateQuestionLibraryCategories < ActiveRecord::Migration[8.1]
  def up
    change_column_null :question_library_entries, :category, true

    create_table :question_library_categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :question_library_categories, [:user_id, :name], unique: true

    execute <<~SQL.squish
      INSERT INTO question_library_categories (user_id, name, created_at, updated_at)
      SELECT user_id, category, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM question_library_entries
      WHERE category IS NOT NULL AND btrim(category) <> ''
      GROUP BY user_id, category
    SQL
  end

  def down
    drop_table :question_library_categories
    change_column_null :question_library_entries, :category, false
  end
end
