class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :account_owner, null: false, foreign_key: { to_table: :users }
      t.references :user, null: true, foreign_key: true
      t.string :email, null: false
      t.integer :role, null: false, default: 1
      t.string :invitation_token
      t.datetime :invitation_sent_at
      t.datetime :invitation_accepted_at

      t.timestamps
    end

    add_index :memberships, :invitation_token, unique: true
    add_index :memberships, [:account_owner_id, :email], unique: true
  end
end
