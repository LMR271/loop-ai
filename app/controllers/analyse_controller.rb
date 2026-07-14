class AnalyseController < ApplicationController
  RANGES = %w[24h 7d 14d 30d custom].freeze
  CHART_VIEWS = %w[bar line cumulative].freeze

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
    @chart_view = params[:chart_view].presence_in(CHART_VIEWS) || "bar"

    scoped_feedbacks = @loop ? @loop.feedbacks.where(created_at: @from..@to) : Feedback.none
    @feedbacks = scoped_feedbacks.order(created_at: :desc)
    @feedback_counts_by_day = feedback_counts_by_period(scoped_feedbacks)
    @cumulative_feedback_counts = cumulative(@feedback_counts_by_day)
    @day_of_week_counts = scoped_feedbacks.group_by_day_of_week(:created_at, format: "%A").count
    @loop_feedback_counts = loop_feedback_counts
  end

  def feedback_counts_by_period(scoped_feedbacks)
    if (@to - @from) <= 1.day
      scoped_feedbacks.group_by_hour(:created_at, range: @from..@to).count
    else
      scoped_feedbacks.group_by_day(:created_at, range: @from..@to).count
    end
  end

  def loop_feedback_counts
    @loops.to_h { |loop_record| [loop_record.name, loop_record.feedbacks.where(created_at: @from..@to).count] }
  end

  def cumulative(counts_by_period)
    running_total = 0
    counts_by_period.transform_values { |count| running_total += count }
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
