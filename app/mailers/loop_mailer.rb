class LoopMailer < ApplicationMailer
  def invite_respondent(loop_record, email)
    @loop = loop_record
    @respondent_url = respondent_url(loop_record.slug)

    mail to: email, subject: "#{loop_record.name} wants your feedback"
  end

  def new_feedback(feedback)
    @feedback = feedback
    @loop = feedback.loop
    @analyse_url = analyse_url(@loop.slug)

    mail to: @loop.user.email, subject: "New feedback on #{@loop.name}"
  end
end
