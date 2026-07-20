require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "welcome greets the new user and links to their dashboard" do
    user = User.create!(email: "founder@example.com", password: "password123", name: "Jamie Founder")

    mail = UserMailer.welcome(user)

    assert_equal ["founder@example.com"], mail.to
    assert_equal "Welcome to Loop AI", mail.subject
    assert_equal ["hi@getloop.me"], mail.from
    assert_match "Jamie Founder", mail.body.encoded
    assert_match "/dashboard", mail.body.encoded
  end
end
