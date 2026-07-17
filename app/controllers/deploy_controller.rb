class DeployController < ApplicationController
  def index
    loops = current_user.loops.includes(:questions).order(created_at: :desc)
    @draft_loops = loops.where.not(status: :active)
    @active_loops = loops.active
    @active_loops_overview = DashboardStats.new(loops, ["active_loops"]).cards.first
  end
end
