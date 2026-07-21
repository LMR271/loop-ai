# Devise::Mailer subclasses this (see config.parent_mailer in devise.rb) so its
# emails (confirmation, reset password, unlock, etc.) get the branded "mailer"
# layout like the rest of the app's mail, while keeping the "Alerts" sender
# identity system-triggered mail uses instead of ApplicationMailer's default.
class DeviseMailer < ApplicationMailer
  default from: ALERTS_SENDER
end
