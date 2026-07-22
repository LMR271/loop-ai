require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-out visitors see the landing page" do
    get root_path

    assert_response :success
    assert_select "h1", text: "Turn feedback into better decisions."
  end

  test "signed-in visitors are redirected to the dashboard instead of the landing page" do
    user = User.create!(email: "founder@example.com", password: "password123")
    sign_in user

    get root_path

    assert_redirected_to dashboard_path
  end
end
