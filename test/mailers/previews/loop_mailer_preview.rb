# Preview all emails at http://localhost:3000/rails/mailers/loop_mailer
class LoopMailerPreview < ActionMailer::Preview
  def invite_respondent
    LoopMailer.invite_respondent(Loop.first, "respondent@example.com")
  end

  def new_feedback
    LoopMailer.new_feedback(Feedback.first)
  end
end
