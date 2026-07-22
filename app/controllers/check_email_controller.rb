class CheckEmailController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @email = params[:email]
  end
end
