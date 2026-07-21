class Loop < ApplicationRecord
  include PgSearch::Model

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

  pg_search_scope :search_by_name_and_description,
                  against: {
                    name: "A",
                    description: "B"
                  },
                  using: {
                    tsearch: { prefix: true }
                  }

  def locked?
    first_deployed_at.present?
  end

  def editable?
    !locked?
  end

  def unanalyzed_feedback_count
    feedbacks.size - (insight&.analyzed_feedback_count || 0)
  end
end
