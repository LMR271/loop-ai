class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      t.references :loop, null: false, foreign_key: true
      t.text :transcript
      t.string :respondent_email

      t.timestamps
    end
  end
end
