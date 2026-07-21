class DashboardController < ApplicationController
  def index
    @loops = current_organization.loops.includes(:feedbacks)
    @recent_loops = @loops.order(created_at: :desc).limit(3)

    stats = DashboardStats.new(@loops, current_user.dashboard_stat_keys)
    @stats = stats.cards
    @selected_stat_keys = stats.selected_keys
    @stat_keys_for_settings = stats.keys_for_settings
  end

  def update_stat_preferences
    keys = (Array(params[:stat_keys]) & DashboardStats::LABELS.keys).first(DashboardStats::MAX_SELECTED_KEYS)
    current_user.update!(dashboard_stat_keys: keys)
    redirect_to dashboard_path, notice: "Dashboard updated."
  end
end
