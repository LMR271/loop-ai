class AnalyseController < ApplicationController
  RANGES = %w[24h 7d 14d 30d custom].freeze

  def index
    @loops = current_user.loops
    @loop = current_user.loops.order(created_at: :desc).first
    load_loop_data
    render :show
  end

  def show
    @loops = current_user.loops
    @loop = current_user.loops.find_by!(slug: params[:slug])
    load_loop_data
  end

  private

  def load_loop_data
    @range = params[:range].presence_in(RANGES) || "30d"
    @from, @to = range_bounds(@range)

    scoped_feedbacks = @loop ? @loop.feedbacks.where(created_at: @from..@to) : Feedback.none
    @feedbacks = scoped_feedbacks.order(created_at: :desc)
    @feedback_counts_by_day = if (@to - @from) <= 1.day
      scoped_feedbacks.group_by_hour(:created_at, range: @from..@to).count
    else
      scoped_feedbacks.group_by_day(:created_at, range: @from..@to).count
    end
  end

  def range_bounds(range)
    to = Time.current

    case range
    when "24h" then [24.hours.ago, to]
    when "7d" then [7.days.ago, to]
    when "14d" then [14.days.ago, to]
    when "custom"
      from = parse_custom_date(params[:from])&.beginning_of_day
      custom_to = parse_custom_date(params[:to])&.end_of_day
      from && custom_to && from <= custom_to ? [from, custom_to] : [30.days.ago, to]
    else
      [30.days.ago, to]
    end
  end

  def parse_custom_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError, TypeError
    nil
  end
end
