class ApplicationMailer < ActionMailer::Base
  # System-triggered mail (password resets, team invites, feedback alerts) sends
  # from here instead of the default below; keep it in sync with Postmark's
  # verified sender signature and config/initializers/devise.rb's mailer_sender.
  ALERTS_SENDER = "Loop AI Alerts <alerts@getloop.me>".freeze

  default from: "Loop AI Team <hi@getloop.me>"
  layout "mailer"
end
