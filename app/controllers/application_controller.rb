class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_organization, :current_user_workspace_admin?,
                :unseen_feedback_total, :loops_with_new_feedback

  def after_sign_in_path_for(_resource)
    loops_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    root_path
  end

  private

  def current_organization
    current_user&.organization
  end

  def current_user_workspace_admin?
    current_user&.workspace_admin? || false
  end

  def require_workspace_admin!
    return if current_user_workspace_admin?

    redirect_to dashboard_path, alert: "Only workspace admins can do that."
  end

  def loops_with_new_feedback
    loops = current_organization.loops.includes(:insight, :feedbacks)
    loops.select { |loop| loop.unseen_feedback_count.positive? }
  end

  def unseen_feedback_total
    loops_with_new_feedback.sum(&:unseen_feedback_count)
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end
end
