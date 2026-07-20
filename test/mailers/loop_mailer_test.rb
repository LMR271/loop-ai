require "test_helper"

class LoopMailerTest < ActionMailer::TestCase
  test "invite_respondent emails the given address with the loop's public link" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "Customer interviews")

    mail = LoopMailer.invite_respondent(loop_record, "respondent@example.com")

    assert_equal ["respondent@example.com"], mail.to
    assert_equal "Customer interviews wants your feedback", mail.subject
    assert_equal ["hi@getloop.me"], mail.from
    assert_match "/i/#{loop_record.slug}", mail.body.encoded
  end

  test "new_feedback notifies the loop's founder" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "Customer interviews")
    feedback = loop_record.feedbacks.create!(transcript: "It was great", sentiment: "positive")

    mail = LoopMailer.new_feedback(feedback)

    assert_equal ["founder@example.com"], mail.to
    assert_equal "New feedback on Customer interviews", mail.subject
    assert_equal ["notifications@getloop.me"], mail.from
    assert_equal ["hi@getloop.me"], mail.reply_to
    assert_match "Positive", mail.body.encoded
  end
end
