class AddConversationIdToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :conversation_id, :string
    add_index :feedbacks, :conversation_id, unique: true
  end
end
