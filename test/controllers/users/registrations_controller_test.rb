require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    test "signing up sends a confirmation email, not a welcome email, and redirects to check your email" do
      without_auto_confirm do
        assert_emails 1 do
          post user_registration_path, params: {
            user: { email: "newfounder@example.com", password: "password123", password_confirmation: "password123" }
          }
        end
      end

      user = User.find_by!(email: "newfounder@example.com")
      assert_not user.confirmed?
      assert_redirected_to check_email_path(email: "newfounder@example.com")
      assert_equal "Confirmation instructions", ActionMailer::Base.deliveries.last.subject

      welcome_job = enqueued_jobs.find { |job| job[:args].first == "UserMailer" }
      assert_nil welcome_job, "welcome email should wait until the account is confirmed"
    end

    test "a failed sign up does not send any email" do
      without_auto_confirm do
        assert_no_enqueued_emails do
          post user_registration_path, params: {
            user: { email: "invalid", password: "short", password_confirmation: "different" }
          }
        end
      end
    end

    test "confirming the account signs the user in, sends the welcome email, and flags the org setup banner" do
      without_auto_confirm do
        post user_registration_path, params: {
          user: { email: "newfounder@example.com", password: "password123", password_confirmation: "password123" }
        }
      end

      user = User.find_by!(email: "newfounder@example.com")

      get user_confirmation_path(confirmation_token: user.confirmation_token)

      assert_redirected_to dashboard_path
      assert_equal "Your account has been confirmed!", flash[:notice]
      assert flash[:show_org_setup]

      welcome_job = enqueued_jobs.find { |job| job[:args].first == "UserMailer" }
      assert welcome_job, "expected a UserMailer delivery job to be enqueued after confirming"
      assert_equal "welcome", welcome_job[:args][1]

      follow_redirect!
      assert_response :success
    end
  end
end
