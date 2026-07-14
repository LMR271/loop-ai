# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

founder = User.find_or_create_by!(email: "founder@loopai.dev") do |user|
  user.name = "Founder"
  user.password = "password123"
  user.password_confirmation = "password123"
end

onboarding_loop = Loop.find_or_create_by!(user: founder, name: "Onboarding Pulse") do |loop_record|
  loop_record.description = "How new users feel in their first week."
  loop_record.status = 1
end

[
  "What made you sign up for LoopAI?",
  "Was there anything confusing during setup?",
  "What almost made you give up before finishing onboarding?"
].each_with_index do |body, index|
  Question.find_or_create_by!(loop: onboarding_loop, body: body) do |question|
    question.position = index + 1
  end
end

[
  {
    respondent_email: "amara@indiehacker.io",
    transcript: <<~TEXT
      Agent: Hi! What made you sign up for LoopAI?
      Respondent: I run a small SaaS and I was drowning in Google Form responses nobody wanted to fill out. A friend said the chat format actually gets people talking.
      Agent: Was there anything confusing during setup?
      Respondent: Honestly no, it took me like 5 minutes to create my first loop and share the link.
      Agent: What almost made you give up before finishing onboarding?
      Respondent: Nothing really, but I was nervous my users wouldn't bother chatting with a bot instead of a form. Turns out they liked it more.
    TEXT
  },
  {
    respondent_email: nil,
    transcript: <<~TEXT
      Agent: What made you sign up for LoopAI?
      Respondent: Curiosity mostly, I wanted to see how an AI-run interview would feel from the other side.
      Agent: Was there anything confusing during setup?
      Respondent: The slug in the URL looked a little random, I wasn't sure if the link was legit at first.
      Agent: What almost made you give up before finishing onboarding?
      Respondent: Nothing serious, it was a smooth experience overall.
    TEXT
  },
  {
    respondent_email: "devon@buildwithdevon.com",
    transcript: <<~TEXT
      Agent: What made you sign up for LoopAI?
      Respondent: I wanted feedback that felt like a real conversation instead of a survey with five-point scales.
      Agent: Was there anything confusing during setup?
      Respondent: A little, I didn't realize I could add my own questions until I poked around the dashboard.
      Agent: What almost made you give up before finishing onboarding?
      Respondent: I got distracted and came back to it two days later, but the loop link still worked fine.
    TEXT
  }
].each do |attrs|
  Feedback.find_or_create_by!(loop: onboarding_loop, respondent_email: attrs[:respondent_email]) do |feedback|
    feedback.transcript = attrs[:transcript]
  end
end

pricing_loop = Loop.find_or_create_by!(user: founder, name: "Pricing Page Feedback") do |loop_record|
  loop_record.description = "Understanding hesitation around the new pricing tiers."
  loop_record.status = 1
end

[
  "What's your first reaction to our pricing page?",
  "Is there a plan that feels right for you? Why or why not?",
  "What would make you more confident about upgrading?"
].each_with_index do |body, index|
  Question.find_or_create_by!(loop: pricing_loop, body: body) do |question|
    question.position = index + 1
  end
end

[
  {
    respondent_email: "priya@northwind.co",
    transcript: <<~TEXT
      Agent: What's your first reaction to our pricing page?
      Respondent: It's clean, but I had to scroll to find what's actually different between Pro and Team.
      Agent: Is there a plan that feels right for you? Why or why not?
      Respondent: Pro, probably, but I'm the only one on my team who'd use it right now.
      Agent: What would make you more confident about upgrading?
      Respondent: A short trial of Team features would help me convince my cofounder.
    TEXT
  },
  {
    respondent_email: nil,
    transcript: <<~TEXT
      Agent: What's your first reaction to our pricing page?
      Respondent: A bit steep for a solo founder honestly, but I get why given what it replaces.
      Agent: Is there a plan that feels right for you? Why or why not?
      Respondent: The starter plan, since I only run one loop at a time.
      Agent: What would make you more confident about upgrading?
      Respondent: Clearer examples of the AI summaries in action, not just a feature list.
    TEXT
  }
].each do |attrs|
  Feedback.find_or_create_by!(loop: pricing_loop, respondent_email: attrs[:respondent_email]) do |feedback|
    feedback.transcript = attrs[:transcript]
  end
end

churn_loop = Loop.find_or_create_by!(user: founder, name: "Churned Users Check-in") do |loop_record|
  loop_record.description = "Learning why customers cancel their subscription."
  loop_record.status = 0
end

[
  "What led you to cancel your subscription?",
  "Was there a specific moment things went wrong?",
  "What could we have done differently to keep you?"
].each_with_index do |body, index|
  Question.find_or_create_by!(loop: churn_loop, body: body) do |question|
    question.position = index + 1
  end
end

# No feedback yet for this loop, on purpose, to exercise the empty state.
