namespace :analysis do
  desc "Enqueue Stage 1 extraction for feedback that has none yet"
  task backfill: :environment do
    Feedback.where(extracted_points: {}).find_each do |feedback|
      AnalyzeFeedbackJob.perform_later(feedback)
    end
  end
end
