class AddSentimentToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :sentiment, :string
    add_column :feedbacks, :sentiment_rationale, :text
  end
end
