require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "requests to the naked domain redirect permanently to www" do
    host! "getloop.me"

    get root_path

    assert_response :moved_permanently
    assert_redirected_to "https://www.getloop.me/"
  end

  test "requests to the naked domain preserve the path and query string" do
    host! "getloop.me"

    get "/users/sign_in", params: { foo: "bar" }

    assert_redirected_to "https://www.getloop.me/users/sign_in?foo=bar"
  end

  test "requests already on www are not redirected" do
    host! "www.getloop.me"

    get root_path

    assert_response :success
  end

  test "requests on other hosts (e.g. local dev, the Heroku dyno URL) are not redirected" do
    get root_path

    assert_response :success
  end
end
