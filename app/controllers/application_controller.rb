class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper_method :current_organization, :current_user_workspace_admin?,
                :new_feedback_total, :loops_with_new_feedback, :new_feedback_count_for

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
    loops = current_organization.loops.includes(:feedbacks)
    loops.select { |loop_record| new_feedback_count_for(loop_record).positive? }
  end

  def new_feedback_count_for(loop_record)
    seen = loop_seen_counts[loop_record.id].to_i
    [loop_record.feedbacks.size - seen, 0].max
  end

  def new_feedback_total
    loops_with_new_feedback.sum { |loop_record| new_feedback_count_for(loop_record) }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end

  def loop_seen_counts
    @loop_seen_counts ||= current_user.loop_views.pluck(:loop_id, :last_seen_feedback_count).to_h
  end
end
