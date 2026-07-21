class WorkspaceController < ApplicationController
  before_action :require_workspace_owner!, only: :destroy

  def update
    if current_organization.update(organization_params)
      redirect_to edit_user_registration_path, notice: "Organization updated."
    else
      redirect_to edit_user_registration_path, alert: current_organization.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.organization.destroy!
    redirect_to edit_user_registration_path, notice: "Your workspace has been deleted."
  end

  private

  def organization_params
    params.require(:organization).permit(:name)
  end

  def require_workspace_owner!
    return if current_user.workspace_owner?

    redirect_to dashboard_path, alert: "Only the workspace owner can delete the workspace."
  end
end
