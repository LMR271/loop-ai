require "test_helper"

module Users
  class ConfirmationsControllerTest < ActionDispatch::IntegrationTest
    test "an expired confirmation link redirects to sign in with an expired message" do
      user = nil
      without_auto_confirm do
        user = User.create!(email: "expired@example.com", password: "password123")
      end
      user.update_column(:confirmation_sent_at, 3.days.ago)

      get user_confirmation_path(confirmation_token: user.confirmation_token)

      assert_redirected_to new_user_session_path
      assert_equal "This confirmation link has expired. Please sign in to request a new one.", flash[:alert]
      assert_nil user.reload.confirmed_at
    end

    test "confirming an already-confirmed account redirects to sign in with an already-confirmed message" do
      user = nil
      without_auto_confirm do
        user = User.create!(email: "already@example.com", password: "password123")
      end
      token = user.confirmation_token
      user.confirm

      get user_confirmation_path(confirmation_token: token)

      assert_redirected_to new_user_session_path
      assert_equal "This account has already been confirmed. Please sign in.", flash[:alert]
    end
  end
end
