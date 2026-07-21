require "test_helper"

class QuestionLibraryCategoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "category-owner@example.com", password: "password123")
    sign_in @user
  end

  test "creates an empty category" do
    assert_difference("QuestionLibraryCategory.count", 1) do
      post question_library_categories_path, params: { question_library_category: { name: "Research" } }
    end

    assert_redirected_to question_library_entries_path
  end

  test "renaming a category keeps its questions" do
    category = @user.question_library_categories.create!(name: "Research")
    entry = @user.question_library_entries.create!(category: "Research", content: "What changed?")

    patch question_library_category_path(category), params: { question_library_category: { name: "Customer research" } }

    assert_redirected_to question_library_entries_path
    assert_equal "Customer research", entry.reload.category
    assert_equal "Customer research", category.reload.name
  end

  test "deleting a category can move its questions to no category" do
    category = @user.question_library_categories.create!(name: "Research")
    entry = @user.question_library_entries.create!(category: "Research", content: "What changed?")

    assert_difference("QuestionLibraryCategory.count", -1) do
      delete question_library_category_path(category), params: { destination: "no_category" }
    end

    assert_nil entry.reload.category
    assert_equal 1, QuestionLibraryEntry.count
  end

  test "deleting a category can move its questions to another category" do
    source = @user.question_library_categories.create!(name: "Research")
    destination = @user.question_library_categories.create!(name: "Interviews")
    entry = @user.question_library_entries.create!(category: "Research", content: "What changed?")

    delete question_library_category_path(source), params: { destination: "move", move_to: destination.id }

    assert_redirected_to question_library_entries_path
    assert_equal "Interviews", entry.reload.category
    assert_not QuestionLibraryCategory.exists?(source.id)
  end

  test "does not allow managing another user's category" do
    other_user = User.create!(email: "other-category-owner@example.com", password: "password123")
    category = other_user.question_library_categories.create!(name: "Private")

    get edit_question_library_category_path(category)

    assert_response :not_found
  end
end
