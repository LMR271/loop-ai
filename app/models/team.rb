class Team < ApplicationRecord
  has_secure_token :invitation_token

  belongs_to :organization
  belongs_to :user, optional: true

  enum :role, { admin: 0, editor: 1 }

  validates :email, presence: true, uniqueness: { scope: :organization_id }

  scope :pending, -> { where(invitation_accepted_at: nil) }

  def accepted?
    invitation_accepted_at.present?
  end
end
