module Users
  class RegistrationsController < Devise::RegistrationsController
    def create
      super do |resource|
        UserMailer.welcome(resource).deliver_later if resource.persisted?
      end
    end

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
  end
end
