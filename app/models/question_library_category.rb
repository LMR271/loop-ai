class QuestionLibraryCategory < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  def entries
    user.question_library_entries.where(category: name)
  end
end
