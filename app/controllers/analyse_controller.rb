class AnalyseController < ApplicationController
  def index
    @loops = current_user.loops
    @loop = current_user.loops.order(created_at: :desc).first
    @feedbacks = @loop&.feedbacks&.order(created_at: :desc) || []
    render :show
  end

  def show
    @loops = current_user.loops
    @loop = current_user.loops.find_by!(slug: params[:slug])
    @feedbacks = @loop.feedbacks.order(created_at: :desc)
  end
end
