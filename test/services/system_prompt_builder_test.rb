require "test_helper"

class SystemPromptBuilderTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "prompt@example.com", password: "password123")
    @loop = user.loops.create!(name: "Onboarding", description: "Understand onboarding")
    @loop.questions.create!(body: "What worked?", position: 2)
    @loop.questions.create!(body: "What didn't?", position: 1)
  end

  test "numbers questions by position" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match("1. What didn't?", prompt)
    assert_match("2. What worked?", prompt)
  end

  test "briefs the agent with the loop name and description" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match("Onboarding", prompt)
    assert_match("Understand onboarding", prompt)
  end

  # The name and description are the loop owner's internal framing, not the
  # respondent's. The agent gets them so it understands the call, then has to
  # paraphrase rather than read them out.
  test "marks the briefing internal and forbids quoting it" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match(/# Briefing \(internal/, prompt)
    assert_match(/never (say|read it out, quote)/, prompt)
  end

  test "tells the agent to paraphrase the subject before question 1" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match(/your own plain words/, prompt)
    assert_match(/question 1/, prompt)
  end

  # A respondent asking "what is this about?" is exactly when the agent reaches
  # for the most specific text it has, which is the briefing.
  test "pins the answer to a direct question about the call to the same generality" do
    assert_match(/asks what this is about/, SystemPromptBuilder.new(@loop).call)
  end

  test "tells the agent it has already greeted the respondent" do
    assert_match(/already greeted/, SystemPromptBuilder.new(@loop).call)
  end

  test "tells the agent to end the call when the respondent says goodbye" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match(/says goodbye/, prompt)
    assert_match(/end_call tool/, prompt)
  end

  test "first message thanks the respondent" do
    assert_match(/thank you/i, SystemPromptBuilder.new(@loop).first_message)
  end

  # The opener is static text sent before the LLM runs, so it cannot paraphrase.
  # It therefore has to stay off the topic entirely: anything it said about the
  # loop would be the owner's internal wording read out verbatim.
  test "first message leaks neither the loop name nor its description" do
    message = SystemPromptBuilder.new(@loop).first_message

    refute_match(/Onboarding/, message)
    refute_match(/Understand onboarding/, message)
  end

  # The opener is static text sent before the LLM runs: if it does not hand the turn
  # back with a question, the agent falls silent until the respondent speaks anyway,
  # which is the exact bug first_message exists to fix.
  test "first message ends on a question so the respondent has a cue to reply" do
    assert_match(/\?\z/, SystemPromptBuilder.new(@loop).first_message)
  end
end
