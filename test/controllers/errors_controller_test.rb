require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  test "404 renders the branded not-found page without authentication" do
    get "/404"

    assert_response :not_found
    assert_select "h1", text: "Page not found"
  end

  test "422 renders the branded page" do
    get "/422"

    assert_response :unprocessable_entity
    assert_select "h1", text: "That request didn't go through"
  end

  test "500 renders the branded page" do
    get "/500"

    assert_response :internal_server_error
    assert_select "h1", text: "Something went wrong on our end"
  end

  test "an unrecognized status code still renders a branded fallback" do
    get "/429"

    assert_response :too_many_requests
    assert_select "h1", text: "Something went wrong"
  end
end
