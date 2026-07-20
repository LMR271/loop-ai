require "test_helper"

module Users
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    test "signing up sends a welcome email" do
      post user_registration_path, params: {
        user: { email: "newfounder@example.com", password: "password123", password_confirmation: "password123" }
      }

      assert User.exists?(email: "newfounder@example.com")
      welcome_job = enqueued_jobs.find { |job| job[:args].first == "UserMailer" }
      assert welcome_job, "expected a UserMailer delivery job to be enqueued"
      assert_equal "welcome", welcome_job[:args][1]
    end

    test "a failed sign up does not send a welcome email" do
      assert_no_enqueued_emails do
        post user_registration_path, params: {
          user: { email: "invalid", password: "short", password_confirmation: "different" }
        }
      end
    end
  end
end
