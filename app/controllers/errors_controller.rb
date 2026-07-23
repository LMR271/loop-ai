class ErrorsController < ApplicationController
  layout "marketing"

  skip_before_action :authenticate_user!

  COPY = {
    400 => { title: "Bad request", message: "That request couldn't be understood. Try going back and trying again." },
    404 => { title: "Page not found", message: "The page you're looking for doesn't exist, or may have moved." },
    406 => { title: "Unsupported browser",
             message: "Please update your browser, or try a different one, to use Loop AI." },
    422 => { title: "That request didn't go through",
             message: "Something about that request couldn't be processed. Try going back and trying again." },
    500 => { title: "Something went wrong on our end",
             message: "We've been notified and are looking into it. Please try again in a moment." }
  }.freeze
  DEFAULT_COPY = { title: "Something went wrong", message: "Please try again in a moment." }.freeze

  def show
    @code = params[:code].to_i
    copy = COPY.fetch(@code, DEFAULT_COPY)
    @title = copy[:title]
    @message = copy[:message]

    render status: @code
  end
end
