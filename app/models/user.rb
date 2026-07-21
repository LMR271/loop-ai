class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :loops
  has_many :question_library_entries, dependent: :destroy
  has_many :question_library_categories, dependent: :destroy
  has_many :team_memberships, class_name: "Team", foreign_key: :account_owner_id, dependent: :destroy
  has_one :owned_organization, class_name: "Organization", foreign_key: :owner_id, dependent: :destroy,
                               inverse_of: :owner
  has_many :team_invitations, class_name: "Team", dependent: :destroy
  has_one :accepted_team_membership, -> { where.not(invitation_accepted_at: nil) }, class_name: "Team"

  after_create :provision_owned_organization

  # The organization whose loops this user should see: their own, unless
  # they've accepted an invite to join another founder's organization as a teammate.
  def organization
    accepted_team_membership&.organization || owned_organization
  end

  def workspace_role
    accepted_team_membership&.role || "admin"
  end

  def workspace_admin?
    workspace_role == "admin"
  end

  # Every user gets their own (usually-empty) owned_organization on signup, even
  # teammates who go on to join someone else's org - so "owns an organization" only
  # means something for the org they're actually operating in right now.
  def workspace_owner?
    organization.owner_id == id
  end

  def loops
    organization&.loops || Loop.none
  end

  def team_memberships
    organization&.team_memberships || Team.none
  end

  private

  def provision_owned_organization
    create_owned_organization!(name: organization_name)
  end
end
