class ChangePendingApprovalDefaultOnLoops < ActiveRecord::Migration[8.1]
  def change
    Loop.where(pending_approval: nil).update_all(pending_approval: false)
    change_column_null :loops, :pending_approval, false
    change_column_default :loops, :pending_approval, from: nil, to: false
  end
end
