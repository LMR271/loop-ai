class RemoveSentimentFromInsights < ActiveRecord::Migration[8.1]
  def change
    remove_column :insights, :sentiment, :string
  end
end
