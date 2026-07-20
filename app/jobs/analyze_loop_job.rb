class AnalyzeLoopJob < ApplicationJob
  queue_as :default

  def perform(loop_record)
    analyzer = LoopAnalyzer.new(loop_record)
    LoopInsightWriter.new(loop_record, analyzer.call, analyzer.analyzed_count).call
  end
end
