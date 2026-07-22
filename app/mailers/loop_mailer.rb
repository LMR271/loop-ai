class LoopMailer < ApplicationMailer
  def invite_respondent(loop_record, email)
    @loop = loop_record
    @organization_name = loop_record.user.organization_name.presence || loop_record.name
    @respondent_url = respondent_url(loop_record.slug)

    mail to: email, subject: "#{@organization_name} wants your feedback"
  end

  def new_feedback(feedback)
    @feedback = feedback
    @loop = feedback.loop
    @analyze_url = analyze_url(@loop.slug)

    mail to: @loop.organization.owner.email, from: ALERTS_SENDER, reply_to: "hi@getloop.me",
         subject: "New feedback on #{@loop.name}"
  end
end
