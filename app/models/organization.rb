class Organization < ApplicationRecord
  belongs_to :owner, class_name: "User"
  has_many :loops, dependent: :destroy
  has_many :team_memberships, class_name: "Team", dependent: :destroy
end
