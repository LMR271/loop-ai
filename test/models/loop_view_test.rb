require "test_helper"

class LoopViewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    @loop = @user.loops.create!(name: "L")
  end

  test "defaults last_seen_feedback_count to 0" do
    loop_view = LoopView.create!(user: @user, loop: @loop)

    assert_equal 0, loop_view.last_seen_feedback_count
  end

  test "enforces one row per user and loop" do
    LoopView.create!(user: @user, loop: @loop, last_seen_feedback_count: 1)
    duplicate = LoopView.new(user: @user, loop: @loop, last_seen_feedback_count: 2)

    assert_not duplicate.valid?
  end
end
