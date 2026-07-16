class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :loops
  has_many :team_memberships, class_name: "Team", foreign_key: :account_owner_id, dependent: :destroy
  has_many :team_invitations, class_name: "Team", dependent: :destroy
  has_one :accepted_team_membership, -> { where.not(invitation_accepted_at: nil) }, class_name: "Team"

  # The user whose loops this user should see: themselves, unless they've
  # accepted an invite to join another founder's workspace as a teammate.
  def workspace_owner
    accepted_team_membership&.account_owner || self
  end

  def workspace_role
    accepted_team_membership&.role || "admin"
  end

  def workspace_admin?
    workspace_role == "admin"
  end
end
