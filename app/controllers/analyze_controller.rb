class AnalyzeController < ApplicationController
  RANGES = %w[24h 7d 14d 30d custom].freeze
  CHART_TYPES = %w[bar line].freeze
  DATA_VIEWS = %w[volume day_of_week cumulative].freeze
  SORTS = %w[newest name feedback_count].freeze
  TABS = %w[all_loops per_loop].freeze

  def index
    @loops = current_organization.loops
    @loop = current_organization.loops.with_insight_quotes.order(created_at: :desc).first
    load_shared_data
    render :show
  end

  def show
    @loops = current_organization.loops
    @loop = current_organization.loops.with_insight_quotes.find_by!(slug: params[:slug])
    load_shared_data
  end

  def refresh
    loop_record = current_organization.loops.find_by!(slug: params[:slug])
    AnalyzeLoopJob.perform_later(loop_record)
    redirect_to analyze_path(loop_record.slug), notice: "Analysis started — this can take a moment."
  end

  def backfill
    loop_record = current_organization.loops.find_by!(slug: params[:slug])
    pending = loop_record.feedbacks_pending_extraction.to_a
    pending.each { |feedback| AnalyzeFeedbackJob.perform_later(feedback) }
    notice = "Analyzing #{pending.size} #{'response'.pluralize(pending.size)} in the background — " \
             "Refresh when it's done."
    redirect_to analyze_path(loop_record.slug), notice: notice
  end

  private

  def load_shared_data
    LoopView.stamp!(user: current_user, loop: @loop) if @loop

    @active_tab = params[:tab].presence_in(TABS) || "per_loop"
    @range = params[:range].presence_in(RANGES) || "30d"
    @from, @to = range_bounds(@range)

    load_per_loop_data
    load_all_loops_data
  end

  def load_per_loop_data
    @chart_type = params[:chart_type].presence_in(CHART_TYPES) || "bar"
    @data_view = params[:data_view].presence_in(DATA_VIEWS) || "volume"

    scoped_feedbacks = @loop ? @loop.feedbacks.where(created_at: @from..@to) : Feedback.none
    @feedbacks = scoped_feedbacks.order(created_at: :desc)
    @feedback_counts_by_day = feedback_counts_by_period(scoped_feedbacks)
    @day_of_week_counts = scoped_feedbacks.group_by_day_of_week(:created_at, format: "%A").count
    @active_chart_data = active_chart_data
    @interview_numbers = interview_numbers_for(@loop)
  end

  def interview_numbers_for(loop_record)
    return {} unless loop_record

    loop_record.feedbacks.order(:created_at).ids.each_with_index.to_h { |id, index| [id, index + 1] }
  end

  def active_chart_data
    case @data_view
    when "day_of_week" then @day_of_week_counts
    when "cumulative" then cumulative(@feedback_counts_by_day)
    else @feedback_counts_by_day
    end
  end

  def load_all_loops_data
    @loop_feedback_counts = loop_feedback_counts

    @status_filter = params[:status_filter].presence_in(%w[all] + Loop.statuses.keys) || "all"
    @sort = params[:sort].presence_in(SORTS) || "newest"

    loops = current_organization.loops.includes(:feedbacks)
    loops = loops.where(status: @status_filter) unless @status_filter == "all"
    @loops_table = LoopTableSorter.new(loops, sort: @sort).call
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
