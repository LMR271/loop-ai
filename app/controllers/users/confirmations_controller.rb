module Users
  class ConfirmationsController < Devise::ConfirmationsController
    def show
      self.resource = resource_class.confirm_by_token(params[:confirmation_token])

      if resource.errors.empty?
        sign_in(resource)
        deliver_welcome_email(resource)
        flash[:show_org_setup] = true if resource.workspace_owner?
        redirect_to dashboard_path, notice: "Your account has been confirmed!"
      else
        redirect_to new_user_session_path, alert: confirmation_error_message(resource)
      end
    end

    private

    def confirmation_error_message(resource)
      if resource.errors.of_kind?(:email, :confirmation_period_expired)
        "This confirmation link has expired. Please sign in to request a new one."
      elsif resource.errors.of_kind?(:email, :already_confirmed)
        "This account has already been confirmed. Please sign in."
      else
        resource.errors.full_messages.to_sentence
      end
    end

    # Invited teammates get the team-specific welcome; everyone else (the
    # person who actually signed up and owns their organization) gets the
    # generic one. Held until confirmation so no one is welcomed to an
    # account before they've proven they own the inbox.
    def deliver_welcome_email(user)
      if user.accepted_team_membership.present?
        TeamMailer.welcome(user.accepted_team_membership).deliver_later
      else
        UserMailer.welcome(user).deliver_later
      end
    end
  end
end
