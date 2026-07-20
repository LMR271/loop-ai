class ApplicationController < ActionController::Base
  before_action :authenticate_user!

  helper_method :current_workspace_owner, :current_user_workspace_admin?,
                :unanalyzed_feedback_total, :loops_with_new_feedback

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

  def loops_with_new_feedback
    loops = current_workspace_owner.loops.includes(:insight, :feedbacks)
    loops.select { |loop| loop.unanalyzed_feedback_count.positive? }
  end

  def unanalyzed_feedback_total
    loops_with_new_feedback.sum(&:unanalyzed_feedback_count)
  end
end
