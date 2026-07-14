class SystemPromptBuilder
  def initialize(loop)
    @loop = loop
  end

  def call
    <<~PROMPT
      # Goal
      #{@loop.description}

      # Questions (ask ONE at a time, in order)
      #{numbered_questions}

      # Rules
      - Ask only one question per message; wait for a full answer.
      - If an answer is vague, probe once: "Could you tell me more about that?"
      - Stay neutral. Don't lead or defend.
      - After the last question, thank them and trigger the end_call tool.
    PROMPT
  end

  private

  def numbered_questions
    @loop.questions.order(:position).map.with_index(1) do |question, number|
      "#{number}. #{question.body}"
    end.join("\n")
  end
end
