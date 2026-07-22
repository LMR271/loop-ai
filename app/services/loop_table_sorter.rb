class LoopTableSorter
  def initialize(loops, sort:)
    @loops = loops
    @sort = sort
  end

  def call
    case @sort
    when "name" then @loops.order(:name)
    when "feedback_count" then @loops.sort_by { |loop_record| -loop_record.feedbacks.size }
    else @loops.order(created_at: :desc)
    end
  end
end
