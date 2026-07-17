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

  test "includes the goal" do
    assert_match "Understand onboarding", SystemPromptBuilder.new(@loop).call
  end

  test "tells the agent it has already greeted the respondent" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match(/already greeted/, prompt)
    assert_match(/question 1/, prompt)
  end

  test "tells the agent to end the call when the respondent says goodbye" do
    prompt = SystemPromptBuilder.new(@loop).call

    assert_match(/says goodbye/, prompt)
    assert_match(/end_call tool/, prompt)
  end

  test "first message thanks the respondent and names the loop" do
    message = SystemPromptBuilder.new(@loop).first_message

    assert_match(/thank you/i, message)
    assert_match("Onboarding", message)
  end

  # The opener is static text sent before the LLM runs: if it does not hand the turn
  # back with a question, the agent falls silent until the respondent speaks anyway,
  # which is the exact bug first_message exists to fix.
  test "first message ends on a question so the respondent has a cue to reply" do
    assert_match(/\?\z/, SystemPromptBuilder.new(@loop).first_message)
  end
end
