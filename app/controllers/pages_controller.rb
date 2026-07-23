class PagesController < ApplicationController
  layout "marketing"

  skip_before_action :authenticate_user!, only: %i[home terms privacy]

  def home
  end

  def terms
  end

  def privacy
  end
end
