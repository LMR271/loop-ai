require "test_helper"

class QuestionLibraryEntryTest < ActiveSupport::TestCase
  test "requires question content but allows no category" do
    entry = QuestionLibraryEntry.new

    assert_not entry.valid?
    assert_includes entry.errors[:content], "can't be blank"
  end

  test "normalizes a blank category to no category" do
    user = User.create!(email: "library-uncategorized@example.com", password: "password123")
    entry = user.question_library_entries.create!(category: "  ", content: "What changed?")

    assert_nil entry.category
  end

  test "starts with no uses" do
    user = User.create!(email: "library-model@example.com", password: "password123")
    entry = user.question_library_entries.create!(category: "Research", content: "What changed?")

    assert_equal 0, entry.times_used
  end

  test "is deleted with its user" do
    user = User.create!(email: "library-delete@example.com", password: "password123")
    user.question_library_entries.create!(category: "Research", content: "What changed?")

    assert_difference("QuestionLibraryEntry.count", -1) { user.destroy! }
  end
end
