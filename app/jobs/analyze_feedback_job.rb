class AnalyzeFeedbackJob < ApplicationJob
  queue_as :default

  def perform(feedback)
    FeedbackAnalyzer.new(feedback).call
  end
end
