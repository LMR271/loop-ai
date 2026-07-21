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
