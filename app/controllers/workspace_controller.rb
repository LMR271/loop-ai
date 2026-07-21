class WorkspaceController < ApplicationController
  before_action :require_workspace_admin!, only: :update
  before_action :require_workspace_owner!, only: :destroy

  def update
    if current_organization.update(organization_params)
      current_organization.logo.purge if current_organization.remove_logo == "1"
      redirect_to update_redirect_path, notice: "Organization updated."
    else
      redirect_to update_redirect_path, alert: current_organization.errors.full_messages.to_sentence
    end
  end

  def destroy
    current_user.organization.destroy!
    redirect_to edit_user_registration_path, notice: "Your workspace has been deleted."
  end

  private

  def update_redirect_path
    return dashboard_path if params[:return_to] == "onboarding"

    edit_user_registration_path
  end

  def organization_params
    params.require(:organization).permit(
      :name, :logo, :remove_logo, :theme_heading_font, :theme_body_font,
      *Organization::THEME_COLOR_ATTRIBUTES
    )
  end

  def require_workspace_owner!
    return if current_user.workspace_owner?

    redirect_to dashboard_path, alert: "Only the workspace owner can delete the workspace."
  end
end
