class DashboardStats
  attr_reader :selected_keys

  LABELS = {
    "active_loops" => "Active Loops",
    "draft_loops" => "Draft Loops",
    "closed_loops" => "Closed Loops",
    "total_loops" => "Total Loops",
    "feedback_this_month" => "Feedback This Month",
    "total_feedback" => "Total Feedback",
    "response_rate" => "Response Rate",
    "feedback_today" => "Feedback Today",
    "feedback_this_week" => "Feedback This Week",
    "avg_feedback_per_loop" => "Avg. Feedback per Loop",
    "anonymous_feedback" => "Anonymous Feedback"
  }.freeze

  DEFAULT_KEYS = %w[active_loops feedback_this_month total_feedback response_rate].freeze
  MAX_SELECTED_KEYS = 4

  # Tile title drops the time period already shown in the subtext; the settings
  # picker keeps using LABELS so options stay distinguishable there.
  DISPLAY_TITLES = {
    "feedback_today" => "Feedback",
    "feedback_this_week" => "Feedback",
    "feedback_this_month" => "Feedback"
  }.freeze

  def initialize(loops, selected_keys)
    @loops = loops
    @selected_keys = selected_keys.presence || DEFAULT_KEYS
    load_loop_counts
    load_feedback_counts
  end

  def cards
    @selected_keys.map { |key| card(key) }
  end

  def keys_for_settings
    @selected_keys + (LABELS.keys - @selected_keys)
  end

  private

  def load_loop_counts
    @active_loops_count = @loops.where(status: :active).count
    @draft_loops_count = @loops.where(status: :draft).count
    @closed_loops_count = @loops.where(status: :closed).count
    @total_loops_count = @loops.count
  end

  def load_feedback_counts
    feedbacks = Feedback.where(loop: @loops)
    @total_feedback_count = feedbacks.count
    @feedback_today_count = feedbacks.where(created_at: Time.current.all_day).count
    @feedback_this_week_count = feedbacks.where(created_at: Time.current.all_week).count
    @feedback_this_month_count = feedbacks.where(created_at: Time.current.all_month).count
    @feedback_last_month_count = feedbacks.where(created_at: 1.month.ago.all_month).count
    @anonymous_feedback_count = feedbacks.where(respondent_email: nil).count
    @avg_feedback_per_loop = average_feedback_per_loop
  end

  def average_feedback_per_loop
    return 0 unless @total_loops_count.positive?

    (@total_feedback_count.to_f / @total_loops_count).round(1)
  end

  def card(key)
    value, subtext = value_and_subtext(key)
    { key: key, label: DISPLAY_TITLES.fetch(key, LABELS[key]), value: value, subtext: subtext }
  end

  def value_and_subtext(key)
    loop_value_and_subtext(key) || feedback_value_and_subtext(key)
  end

  def loop_value_and_subtext(key)
    case key
    when "active_loops" then [@active_loops_count, active_loops_subtext]
    when "draft_loops" then [@draft_loops_count, "loops not yet active"]
    when "closed_loops" then [@closed_loops_count, "no longer collecting"]
    when "total_loops" then [@total_loops_count, "across your workspace"]
    end
  end

  def feedback_value_and_subtext(key)
    case key
    when "feedback_this_month" then [@feedback_this_month_count, "this month"]
    when "total_feedback" then [@total_feedback_count, "all time"]
    when "response_rate" then response_rate_value_and_subtext
    when "feedback_today" then [@feedback_today_count, "today"]
    when "feedback_this_week" then [@feedback_this_week_count, "this week"]
    when "avg_feedback_per_loop" then [@avg_feedback_per_loop, "per loop"]
    when "anonymous_feedback" then [@anonymous_feedback_count, "no email provided"]
    end
  end

  def active_loops_subtext
    parts = []
    parts << count_with_label(@draft_loops_count, "draft") if @draft_loops_count.positive?
    parts << count_with_label(@closed_loops_count, "closed loop") if @closed_loops_count.positive?
    parts.any? ? parts.join(", ") : "All loops active"
  end

  def response_rate_value_and_subtext
    this_month = @feedback_this_month_count
    last_month = @feedback_last_month_count
    return ["—", "No feedback yet"] if this_month.zero? && last_month.zero?
    return ["New", "First feedback this month"] if last_month.zero?

    change = ((this_month - last_month).to_f / last_month * 100).round
    direction = change >= 0 ? "higher" : "lower"
    ["#{change.abs}%", "#{change.abs}% #{direction} than last month"]
  end

  def count_with_label(count, singular)
    "#{count} #{count == 1 ? singular : "#{singular}s"}"
  end
end
