class LoopInsightWriter
  def initialize(loop_record, result, analyzed_count)
    @loop = loop_record
    @result = result
    @analyzed_count = analyzed_count
  end

  def call
    ActiveRecord::Base.transaction do
      @loop.insight&.destroy!
      insight = build_insight
      Array(@result["themes"]).each { |data| build_theme(insight, data) }
      Array(@result["feature_requests"]).each { |data| build_request(insight, data) }
    end
  end

  private

  def build_insight
    @loop.create_insight!(
      summary: @result["summary"], overall_sentiment: @result["overall_sentiment"],
      analyzed_feedback_count: @analyzed_count, generated_at: Time.current
    )
  end

  def build_theme(insight, data)
    theme = insight.themes.create!(data.slice("title", "description", "mention_count", "sentiment"))
    build_quotes(theme, data["citations"])
  end

  def build_request(insight, data)
    request = insight.feature_requests.create!(data.slice("title", "description"))
    build_quotes(request, data["citations"])
  end

  def build_quotes(quotable, citations)
    feedback_ids = quotable.insight.loop.feedbacks.pluck(:id).to_set
    Array(citations).each do |citation|
      next unless feedback_ids.include?(citation["feedback_id"])

      quotable.quotes.create!(feedback_id: citation["feedback_id"], text: citation["quote"])
    end
  end
end
