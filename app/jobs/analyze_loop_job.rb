class AnalyzeLoopJob < ApplicationJob
  queue_as :default

  def perform(loop_record)
    analyzer = LoopAnalyzer.new(loop_record)
    result = analyzer.call
    LoopInsightWriter.new(loop_record, result, analyzer.analyzed_count).call
  rescue LlmClient::Error => e
    Rails.logger.warn("[AnalyzeLoopJob] loop=#{loop_record.id} failed: #{e.message}")
  end
end
