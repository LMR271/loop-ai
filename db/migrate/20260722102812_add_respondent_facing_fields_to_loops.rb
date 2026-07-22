class AddRespondentFacingFieldsToLoops < ActiveRecord::Migration[8.1]
  def change
    add_column :loops, :respondent_title, :string
    add_column :loops, :respondent_description, :text
  end
end
