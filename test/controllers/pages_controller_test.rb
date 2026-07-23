require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-out visitors see the landing page" do
    get root_path

    assert_response :success
    assert_select "h1", text: "Turn feedback into better decisions."
  end

  test "landing page nav links to each one-pager section" do
    get root_path

    assert_response :success
    assert_select "nav a[href='#product']", text: "Product"
    assert_select "nav a[href='#use-cases']", text: "Use Cases"
    assert_select "nav a[href='#faq']", text: "FAQ"
    assert_select "nav a[href='#pricing']", text: "Pricing"
  end

  test "landing page has the Product, Use Cases, FAQ, and Pricing sections" do
    get root_path

    assert_response :success
    assert_select "section#product"
    assert_select "section#use-cases"
    assert_select "section#faq"
    assert_select "section#pricing"
  end

  test "landing page footer shows the copyright" do
    get root_path

    assert_response :success
    assert_select "footer", text: /© #{Time.current.year} Loop AI/
  end

  test "signed-in visitors also see the landing page at root, not a redirect to the dashboard" do
    user = User.create!(email: "founder@example.com", password: "password123")
    sign_in user

    get root_path

    assert_response :success
    assert_select "h1", text: "Turn feedback into better decisions."
  end

  test "signed-out visitors see a Log in link but no Sign up button, since access is by beta application" do
    get root_path

    assert_select "nav a[href='#{new_user_session_path}']", text: "Log in"
    assert_select "nav a", text: "Sign up", count: 0
  end

  test "signed-in visitors see a Dashboard link in the nav instead of Log in/Sign up" do
    user = User.create!(email: "founder@example.com", password: "password123")
    sign_in user

    get root_path

    assert_select "nav a[href='#{dashboard_path}']", text: "Go to Dashboard"
    assert_select "nav a", text: "Log in", count: 0
    assert_select "nav a", text: "Sign up", count: 0
  end

  test "landing page footer links to Terms and Privacy" do
    get root_path

    assert_response :success
    assert_select "footer a[href='#{terms_path}']", text: "Terms"
    assert_select "footer a[href='#{privacy_path}']", text: "Privacy"
  end

  test "terms page renders without authentication" do
    get terms_path

    assert_response :success
    assert_select "h1", text: "Terms of Service"
    assert_select "a[href='#{privacy_path}']"
  end

  test "privacy page renders without authentication" do
    get privacy_path

    assert_response :success
    assert_select "h1", text: "Privacy Policy"
  end
end
