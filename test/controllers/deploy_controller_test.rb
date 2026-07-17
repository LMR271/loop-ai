require "test_helper"

class DeployControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "shows only the signed-in user's inactive loops" do
    draft = @user.loops.create!(name: "Draft research")
    closed = @user.loops.create!(name: "Paused research", status: :closed)
    @user.loops.create!(name: "Live research", status: :active)
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_user.loops.create!(name: "Private draft")

    get deploy_path

    assert_response :success
    assert_select "summary", text: /#{draft.name}/
    assert_select "summary", text: /#{closed.name}/
    assert_select "summary", text: "Live research", count: 0
    assert_select "summary", text: "Private draft", count: 0
    assert_select "form[action='#{activate_loop_path(draft)}']", count: 1
    assert_select "a[href='#{edit_loop_path(draft)}']", text: "Edit loop", count: 1
    assert_select "input[value='#{respondent_url(draft.slug)}']", count: 1
  end
end
