require "test_helper"

class QuestionLibraryEntriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "library-owner@example.com", password: "password123")
    sign_in @user
  end

  test "shows only the signed-in user's entries, alphabetized by category and content" do
    @user.question_library_entries.create!(category: "Research", content: "Zebra question")
    visible = @user.question_library_entries.create!(category: "Customer", content: "Ask this first")
    other_user = User.create!(email: "private-library@example.com", password: "password123")
    other_user.question_library_entries.create!(category: "Customer", content: "Private question")

    get question_library_entries_path

    assert_response :success
    assert_select "h2", text: visible.category
    assert_select "p", text: visible.content
    assert_select "p", text: "Private question", count: 0
  end

  test "creates a library question for the signed-in user" do
    assert_difference("@user.question_library_entries.count", 1) do
      post question_library_entries_path, params: {
        question_library_entry: { category: "Research", content: "What surprised you?" }
      }, as: :json
    end

    assert_response :created
    assert_equal "Research", @user.question_library_entries.last.category
  end

  test "creates a library question without a category" do
    post question_library_entries_path, params: {
      question_library_entry: { category: "", content: "What stood out?" }
    }, as: :json

    assert_response :created
    assert_nil @user.question_library_entries.last.category
  end

  test "shows uncategorized questions before named categories" do
    @user.question_library_entries.create!(category: "Research", content: "Named question")
    @user.question_library_entries.create!(content: "Uncategorized question")

    get question_library_entries_path

    assert_response :success
    assert_select "h2", text: "No Category", count: 1
    assert_select "h2", text: "Research", count: 1
  end

  test "does not allow access to another user's library question" do
    other_user = User.create!(email: "other-library-owner@example.com", password: "password123")
    entry = other_user.question_library_entries.create!(category: "Research", content: "Private question")

    get edit_question_library_entry_path(entry)

    assert_response :not_found
  end

  test "increments uses only for the signed-in user's library question" do
    entry = @user.question_library_entries.create!(category: "Research", content: "What surprised you?")

    post use_question_library_entry_path(entry)

    assert_response :no_content
    assert_equal 1, entry.reload.times_used
  end

  test "deletes a library question with confirmation handled by the interface" do
    entry = @user.question_library_entries.create!(category: "Research", content: "What surprised you?")

    assert_difference("QuestionLibraryEntry.count", -1) do
      delete question_library_entry_path(entry)
    end

    assert_redirected_to question_library_entries_path
  end
end
