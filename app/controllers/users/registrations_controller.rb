module Users
  class RegistrationsController < Devise::RegistrationsController
    def destroy
      return if blocked_by_workspace_ownership?

      Loop.where(user: current_user).update_all(user_id: nil)
      super
    end

    private

    # The workspace owner's Organization (loops, teammates) has nowhere to go if
    # their User account disappears, so they must delete the workspace first.
    def blocked_by_workspace_ownership?
      return false unless current_user.workspace_owner?

      redirect_to edit_user_registration_path,
                  alert: "Delete your workspace before deleting your account."
      true
    end

    # Confirmable blocks sign-in until the email is verified, so a fresh signup
    # lands on a page saying to check their inbox rather than the sign-in page.
    def after_inactive_sign_up_path_for(resource)
      check_email_path(email: resource.email)
    end
  end
end
