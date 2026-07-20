class QuestionLibraryEntry < ApplicationRecord
  belongs_to :user

  validates :content, presence: true
  validates :times_used, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :alphabetical, -> { order(Arel.sql("category NULLS FIRST"), :content) }

  before_validation :normalize_category
  after_save :ensure_category_record

  private

  def normalize_category
    self.category = category.presence
  end

  def ensure_category_record
    user.question_library_categories.find_or_create_by!(name: category) if category.present?
  end
end
