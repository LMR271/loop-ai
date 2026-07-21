class CreateFeatureRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_requests do |t|
      t.references :insight, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status, default: 0, null: false
      t.string :github_issue_url
      t.timestamps
    end
  end
end
