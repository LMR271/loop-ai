class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  helper_method :current_workspace_owner, :current_user_workspace_admin?

  def after_sign_in_path_for(_resource)
    loops_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def current_workspace_owner
    current_user&.workspace_owner
  end

  def current_user_workspace_admin?
    current_user&.workspace_admin? || false
  end

  def require_workspace_admin!
    return if current_user_workspace_admin?

    redirect_to dashboard_path, alert: "Only workspace admins can do that."
  end
end
