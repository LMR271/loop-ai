class Loop < ApplicationRecord
  has_secure_token :slug

  belongs_to :user

  enum :status, { draft: 0, active: 1, closed: 2 }

  has_many :feedbacks, dependent: :destroy
  has_one :insight, dependent: :destroy
  has_many :questions, -> { order(:position, :id) }, dependent: :destroy

  accepts_nested_attributes_for :questions,
                                allow_destroy: true,
                                reject_if: lambda { |attributes|
                                  attributes["body"].blank? && attributes["id"].blank?
                                }

  validates :name, presence: true
end
