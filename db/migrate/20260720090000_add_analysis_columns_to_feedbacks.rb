class AddAnalysisColumnsToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :title, :string
    add_column :feedbacks, :summary, :text
    add_column :feedbacks, :extracted_points, :jsonb, default: {}, null: false
  end
end
