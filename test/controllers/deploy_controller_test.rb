require "test_helper"

class DeployControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    sign_in @user
  end

  test "shows the signed-in user's draft and active loops in separate sections" do
    draft = @user.loops.create!(name: "Draft research")
    closed = @user.loops.create!(name: "Paused research", status: :closed)
    @user.loops.create!(name: "Live research", status: :active)
    other_user = User.create!(email: "other@example.com", password: "password123")
    other_user.loops.create!(name: "Private draft")

    get deploy_path

    assert_response :success
    assert_select "#draft-loops-heading", text: "Draft Loops"
    assert_select "#active-loops-heading", text: "Active Loops"
    assert_select ".deploy-header .deploy-active-overview", text: /Active Loops\s*1\s*1 draft, 1 closed loop/
    assert_select ".col-lg-4 .deploy-active-overview", count: 0
    assert_select "summary", text: /#{draft.name}/
    assert_select "summary", text: /#{closed.name}/
    assert_select ".deploy-active-list .deploy-loop__name", text: "Live research"
    assert_select ".deploy-active-list .badge", text: "Live"
    assert_select "summary", text: "Private draft", count: 0
    assert_select ".deploy-active-list", text: /Private draft/, count: 0
    assert_select "form[action='#{activate_loop_path(draft)}']", count: 1
    assert_select "a[href='#{edit_loop_path(draft)}']", count: 1
    assert_select "input[value='#{respondent_url(draft.slug)}']", count: 0
    assert_select "form[action='#{deactivate_loop_path(@user.loops.find_by!(name: 'Live research'))}']", count: 1
  end

  test "shows the empty state for each loop group independently" do
    get deploy_path

    assert_response :success
    assert_select ".deploy-empty-message", text: "There are no draft loops."
    assert_select ".deploy-empty-message--centered", text: "There are no currently active loops."
  end
end
