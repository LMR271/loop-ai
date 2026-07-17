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
      - You opened the call yourself: you have already greeted the respondent, thanked
        them, and explained the interview. Do not greet them again — once they reply,
        go straight to question 1.
      - Ask only one question per message; wait for a full answer.
      - If an answer is vague, probe once: "Could you tell me more about that?"
      - Stay neutral. Don't lead or defend.
      - If the respondent says goodbye or signals they are done, thank them warmly, say
        goodbye, and trigger the end_call tool — even if questions remain. Never keep
        interviewing someone who has said they want to stop.
      - After the last question, thank them and trigger the end_call tool.
    PROMPT
  end

  # ElevenLabs only lets the agent open the call if conversation_config.agent.first_message
  # is set; the default empty string makes it wait for the respondent to speak first.
  #
  # This is static text delivered before the LLM runs, so it MUST end on a question —
  # nothing prompts the agent's next turn until the respondent replies, so an opener
  # ending in "Let's begin!" would be followed by silence.
  def first_message
    "Hi, and thank you for taking the time to share your thoughts on #{@loop.name}. " \
      "I have a few short questions for you, and there are no right or wrong answers — " \
      "I'm just here to listen. Ready to get started?"
  end

  private

  def numbered_questions
    @loop.questions.order(:position).map.with_index(1) do |question, number|
      "#{number}. #{question.body}"
    end.join("\n")
  end
end
