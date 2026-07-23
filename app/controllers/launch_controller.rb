class LaunchController < ApplicationController
  before_action :set_loop, only: :send_invites

  def index
    loops = current_organization.loops.includes(:questions).order(created_at: :desc)
    @draft_loops = loops.where.not(status: :active)
    @active_loops = loops.active
    @active_loops_overview = DashboardStats.new(loops, ["active_loops"]).cards.first
  end

  def send_invites
    emails = parsed_emails(params[:emails])

    if emails.empty?
      redirect_to launch_path, alert: "Enter at least one valid email address."
    else
      emails.each { |email| LoopMailer.invite_respondent(@loop, email).deliver_later }
      redirect_to launch_path, notice: "Sent #{emails.size} #{'invite'.pluralize(emails.size)}."
    end
  end

  private

  def set_loop
    @loop = current_organization.loops.find(params[:loop_id])
  end

  def parsed_emails(raw)
    raw.to_s.split(/[\s,]+/).map(&:strip).grep(URI::MailTo::EMAIL_REGEXP).uniq
  end
end
