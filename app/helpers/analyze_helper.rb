module AnalyzeHelper
  # Only "excited" gets a solid fill — it's the signal worth spotting across a long list.
  # The rest stay subtle so a page of feedback doesn't read as a bag of sweets.
  SENTIMENT_BADGES = {
    "excited" => %w[Excited text-bg-success],
    "positive" => %w[Positive bg-success-subtle\ text-success-emphasis],
    "neutral" => %w[Neutral bg-secondary-subtle\ text-secondary-emphasis],
    "frustrated" => %w[Frustrated bg-warning-subtle\ text-warning-emphasis],
    "negative" => %w[Negative bg-danger-subtle\ text-danger-emphasis]
  }.freeze

  # Renders nothing for nil: feedback from agents provisioned before data_collection
  # existed has no sentiment, and an empty badge would imply one was measured.
  def sentiment_badge(sentiment)
    label, classes = SENTIMENT_BADGES[sentiment]
    return if label.blank?

    tag.span(label, class: "badge rounded-pill #{classes}")
  end

  # "Interview #N" numbering is assigned by AnalyzeController (oldest feedback = #1) across the
  # loop's whole history, not the page's current date-range filter — see interview_numbers_for.
  # The link forces a custom range covering the interview's own day so the anchor always exists
  # on the target page, regardless of what range was selected when the link was clicked.
  def interview_tag_link(loop_record, feedback, interview_numbers)
    number = interview_numbers.fetch(feedback.id)
    day = feedback.created_at.to_date

    link_to "Interview ##{number}",
            analyze_path(loop_record.slug, range: "custom", from: day, to: day, anchor: "feedback-#{feedback.id}"),
            class: "analysis-quote-tag__link"
  end

  LOOP_STATUS_BADGES = {
    "draft" => "bg-secondary-subtle text-secondary-emphasis",
    "active" => "bg-success-subtle text-success-emphasis",
    "closed" => "bg-dark-subtle text-dark-emphasis"
  }.freeze

  def loop_status_badge(status)
    tag.span(status.capitalize, class: "badge rounded-pill #{LOOP_STATUS_BADGES.fetch(status)}")
  end

  def range_label(range, from, to)
    case range
    when "24h" then "last 24 hours"
    when "7d" then "last 7 days"
    when "14d" then "last 14 days"
    when "custom" then "#{from.to_date.strftime('%b %d, %Y')} – #{to.to_date.strftime('%b %d, %Y')}"
    else "last 30 days"
    end
  end

  def chart_title(chart_view)
    case chart_view
    when "cumulative" then "Cumulative feedback"
    when "day_of_week" then "Responses by day of week"
    else "Feedback volume"
    end
  end
end
