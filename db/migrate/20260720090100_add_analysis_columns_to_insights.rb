class AddAnalysisColumnsToInsights < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :overall_sentiment, :string
    add_column :insights, :analyzed_feedback_count, :integer, default: 0, null: false
    add_column :insights, :generated_at, :datetime
  end
end
