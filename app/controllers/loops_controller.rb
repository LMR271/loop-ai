class LoopsController < ApplicationController
  def index
    @loops = current_user.loops.includes(:feedbacks).order(created_at: :desc)
  end

  def destroy
    loop = current_user.loops.find(params[:id])
    loop.destroy!

    redirect_to loops_path, notice: "Loop deleted."
  end
end
