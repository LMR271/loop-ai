class Loop < ApplicationRecord
  include PgSearch::Model

  has_one_attached :image
  attr_accessor :remove_image

  has_secure_token :slug

  belongs_to :user, optional: true
  belongs_to :organization

  enum :status, { draft: 0, active: 1, closed: 2 }

  has_many :feedbacks, dependent: :destroy
  has_one :insight, dependent: :destroy
  has_many :questions, -> { order(:position, :id) }, dependent: :destroy
  has_many :loop_views, dependent: :destroy

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

  # Eager-loads the whole insight -> theme/feature_request -> quote -> feedback chain the Analyze
  # tiles read (each quote's own interview tag and sentiment), avoiding a query per quote.
  scope :with_insight_quotes, lambda {
    includes(insight: { themes: { quotes: :feedback }, feature_requests: { quotes: :feedback } })
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

  def feedbacks_pending_extraction
    feedbacks.where(extracted_points: {})
  end

  def pending_extraction_count
    feedbacks_pending_extraction.size
  end
end
