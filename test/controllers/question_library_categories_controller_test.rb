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

  test "deleting an empty category removes just the category" do
    category = @user.question_library_categories.create!(name: "Research")

    assert_difference("QuestionLibraryCategory.count", -1) do
      delete question_library_category_path(category)
    end

    assert_redirected_to question_library_entries_path
  end

  test "deleting a category also deletes its questions" do
    category = @user.question_library_categories.create!(name: "Research")
    entry = @user.question_library_entries.create!(category: "Research", content: "What changed?")

    assert_difference("QuestionLibraryCategory.count" => -1, "QuestionLibraryEntry.count" => -1) do
      delete question_library_category_path(category)
    end

    assert_redirected_to question_library_entries_path
    assert_not QuestionLibraryEntry.exists?(entry.id)
  end

  test "does not allow deleting another user's category" do
    other_user = User.create!(email: "other-category-owner@example.com", password: "password123")
    category = other_user.question_library_categories.create!(name: "Private")

    delete question_library_category_path(category)

    assert_response :not_found
  end
end
