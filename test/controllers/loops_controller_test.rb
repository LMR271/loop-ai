require "test_helper"

class LoopsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "index only shows the signed-in user's loops" do
    own_loop = @user.loops.create!(name: "Customer interviews")
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_user.loops.create!(name: "Private loop")

    get loops_path

    assert_response :success
    assert_select "h2", text: own_loop.name
    assert_select "h2", text: "Private loop", count: 0
  end

  test "deleting a loop also deletes its associated records" do
    loop = @user.loops.create!(name: "Old research")
    loop.feedbacks.create!(transcript: "A response")
    loop.questions.create!(body: "What helped?")
    loop.create_insight!(summary: "Useful")

    assert_difference("Loop.count", -1) do
      delete loop_path(loop)
    end

    assert_redirected_to loops_path
    assert_equal 0, Feedback.where(loop_id: loop.id).count
    assert_equal 0, Question.where(loop_id: loop.id).count
    assert_equal 0, Insight.where(loop_id: loop.id).count
  end

  test "a user cannot delete another user's loop" do
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_loop = other_user.loops.create!(name: "Private loop")

    assert_no_difference("Loop.count") do
      delete loop_path(other_loop)
    end

    assert_response :not_found
  end
end
