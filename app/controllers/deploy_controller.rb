class DeployController < ApplicationController
  def index
    @loops = current_user.loops
                         .where.not(status: :active)
                         .includes(:questions)
                         .order(created_at: :desc)
  end
end
