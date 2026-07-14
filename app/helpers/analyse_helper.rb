module AnalyseHelper
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
