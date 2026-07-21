module Users
  class ConfirmationsController < Devise::ConfirmationsController
    def show
      self.resource = resource_class.confirm_by_token(params[:confirmation_token])

      if resource.errors.empty?
        sign_in(resource)
        redirect_to dashboard_path, notice: "Your account has been confirmed!"
      else
        redirect_to new_user_session_path, alert: resource.errors.full_messages.to_sentence
      end
    end
  end
end
