class AddOrganizationToLoops < ActiveRecord::Migration[8.1]
  def change
    add_reference :loops, :organization, null: true, foreign_key: true
  end
end
