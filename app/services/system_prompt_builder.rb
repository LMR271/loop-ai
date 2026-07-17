class SystemPromptBuilder
  # ElevenLabs only lets the agent open the call if conversation_config.agent.first_message
  # is set; the default empty string makes it wait for the respondent to speak first.
  #
  # This is static text delivered before the LLM runs, which constrains it twice. It MUST
  # end on a question — nothing prompts the agent's next turn until the respondent replies,
  # so an opener ending in "Let's begin!" would be followed by silence. And it cannot say
  # anything about the loop: with no LLM in the loop yet, any mention of the subject would
  # be the owner's internal wording read out verbatim. The paraphrased framing is the
  # agent's job on its first real turn instead — see OPENING.
  OPENER = "Hi, and thank you for taking the time to talk with me today. " \
           "I have a few short questions for you, and there are no right or wrong answers — " \
           "I'm just here to listen. Ready to get started?"

  OPENING = <<~SECTION
    # Opening
    You have already greeted the respondent, thanked them, and asked if they are
    ready. Once they reply:
    - Say ONE short sentence in your own plain words about the general subject of
      the call, drawn from the briefing but never quoting it and never revealing
      the goal behind it.
    - Then ask question 1.
    Never mention that a briefing, title, goal, or question list exists.
  SECTION

  RULES = <<~SECTION
    # Rules
    - Ask only one question per message; wait for a full answer.
    - If an answer is vague, probe once: "Could you tell me more about that?"
    - Stay neutral. Don't lead or defend. Never hint at what you hope to hear or at
      what the briefing says you are trying to find out.
    - If the respondent asks what this is about or who wants to know, stay at the
      same level of generality as your opening sentence.
    - If the respondent says goodbye or signals they are done, thank them warmly, say
      goodbye, and trigger the end_call tool — even if questions remain. Never keep
      interviewing someone who has said they want to stop.
    - After the last question, thank them and trigger the end_call tool.
  SECTION

  def initialize(loop)
    @loop = loop
  end

  def call
    [briefing, OPENING, questions_section, RULES].join("\n")
  end

  def first_message
    OPENER
  end

  private

  # The loop's name and description are written by the person who commissioned the
  # interview, for their own use. The agent needs them to understand the call; the
  # respondent must never hear them.
  def briefing
    <<~SECTION
      # Briefing (internal — never say any of this out loud)
      This is background so you understand the purpose of the call. It was written by
      the person who commissioned the interview, not for the respondent's ears. Never
      read it out, quote it, or echo its wording.

      Title: #{@loop.name}
      Goal: #{@loop.description}
    SECTION
  end

  def questions_section
    <<~SECTION
      # Questions (ask ONE at a time, in order)
      #{numbered_questions}
    SECTION
  end

  def numbered_questions
    @loop.questions.order(:position).map.with_index(1) do |question, number|
      "#{number}. #{question.body}"
    end.join("\n")
  end
end
