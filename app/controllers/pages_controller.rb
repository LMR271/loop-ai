class PagesController < ApplicationController
  layout "marketing"

  skip_before_action :authenticate_user!, only: [:home]

  def home
  end
end
