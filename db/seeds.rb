# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

FIRST_NAMES = %w[
  Alex Jordan Sam Taylor Casey Morgan Riley Jamie Avery Reese Quinn Skyler Rowan Emerson Dakota Harper
].freeze
BULK_RESPONDENT_DOMAIN = "demo.loopai.dev".freeze

# Skews toward more recent days so daily counts trend upward instead of sitting flat,
# while staying safely inside a 30-day window regardless of what time seeds run.
def weighted_recent_timestamp(max_days_ago: 28)
  days_ago = (max_days_ago * (1 - Math.sqrt(rand))).floor
  Time.current.beginning_of_day - days_ago.days + rand(9..21).hours + rand(0..59).minutes
end

def random_bulk_respondent_email
  return nil if rand < 0.25

  "#{FIRST_NAMES.sample.downcase}#{rand(10..999)}@#{BULK_RESPONDENT_DOMAIN}"
end

def build_transcript(qa_pairs)
  qa_pairs.map { |question, answer| "Agent: #{question}\nRespondent: #{answer}" }.join("\n")
end

# Bulk feedback is tagged with a recognizable respondent domain so reseeding can detect
# it already ran and skip, without relying on find_or_create_by! (which would collapse
# every nil-email record into one, since nil is treated as an equal match for lookup).
def seed_bulk_feedback!(loop_record, questions_and_answers:, count:)
  return if loop_record.feedbacks.where("respondent_email LIKE ?", "%@#{BULK_RESPONDENT_DOMAIN}").exists?

  count.times do
    qa_pairs = questions_and_answers.map { |question, answers| [question, answers.sample] }
    Feedback.create!(
      loop: loop_record,
      respondent_email: random_bulk_respondent_email,
      transcript: build_transcript(qa_pairs),
      created_at: weighted_recent_timestamp
    )
  end
end

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

feature_request_loop = Loop.find_or_create_by!(user: founder, name: "Feature Request Roundup") do |loop_record|
  loop_record.description = "Understanding what to build next based on real user requests."
  loop_record.status = 2
end

[
  "What's the one feature you wish LoopAI had right now?",
  "How are you working around not having it today?",
  "How would this feature change the way you use LoopAI?"
].each_with_index do |body, index|
  Question.find_or_create_by!(loop: feature_request_loop, body: body) do |question|
    question.position = index + 1
  end
end

[
  {
    respondent_email: "noah@trycadence.io",
    transcript: <<~TEXT
      Agent: What's the one feature you wish LoopAI had right now?
      Respondent: Native export to CSV. I want to pull transcripts into our own analytics stack.
      Agent: How are you working around not having it today?
      Respondent: Copy-pasting transcripts into a spreadsheet manually, which is slow and error-prone.
      Agent: How would this feature change the way you use LoopAI?
      Respondent: I'd trust it as our source of truth instead of treating it as a side tool.
    TEXT
  },
  {
    respondent_email: nil,
    transcript: <<~TEXT
      Agent: What's the one feature you wish LoopAI had right now?
      Respondent: Tagging or categorizing feedback automatically by topic.
      Agent: How are you working around not having it today?
      Respondent: Reading every transcript myself and mentally grouping the themes.
      Agent: How would this feature change the way you use LoopAI?
      Respondent: I could spend way less time triaging and more time acting on it.
    TEXT
  },
  {
    respondent_email: "greta@flowstack.dev",
    transcript: <<~TEXT
      Agent: What's the one feature you wish LoopAI had right now?
      Respondent: The ability to reopen a conversation if a respondent wants to add more later.
      Agent: How are you working around not having it today?
      Respondent: Asking them to just start a new one and mentioning it's a follow-up.
      Agent: How would this feature change the way you use LoopAI?
      Respondent: It would make longer-term check-ins feel like one continuous relationship.
    TEXT
  }
].each do |attrs|
  Feedback.find_or_create_by!(loop: feature_request_loop, respondent_email: attrs[:respondent_email]) do |feedback|
    feedback.transcript = attrs[:transcript]
  end
end

support_loop = Loop.find_or_create_by!(user: founder, name: "Support Experience Review") do |loop_record|
  loop_record.description = "Checking in after a support ticket to see how it went."
  loop_record.status = 1
end

[
  "How would you rate your recent support experience?",
  "Was your issue fully resolved?",
  "What could we have done better?"
].each_with_index do |body, index|
  Question.find_or_create_by!(loop: support_loop, body: body) do |question|
    question.position = index + 1
  end
end

[
  {
    respondent_email: "mika@northlightstudio.com",
    transcript: <<~TEXT
      Agent: How would you rate your recent support experience?
      Respondent: Pretty good, the response came back within a couple hours.
      Agent: Was your issue fully resolved?
      Respondent: Yes, the slug redirect bug I reported got fixed the same day.
      Agent: What could we have done better?
      Respondent: Maybe a status page so I didn't have to ask if it was a known issue.
    TEXT
  },
  {
    respondent_email: nil,
    transcript: <<~TEXT
      Agent: How would you rate your recent support experience?
      Respondent: It was fine, though it took a couple of back-and-forths to get to the actual fix.
      Agent: Was your issue fully resolved?
      Respondent: Eventually yes, but it took about three days.
      Agent: What could we have done better?
      Respondent: A bit more proactive updates while it was being looked into.
    TEXT
  }
].each do |attrs|
  Feedback.find_or_create_by!(loop: support_loop, respondent_email: attrs[:respondent_email]) do |feedback|
    feedback.transcript = attrs[:transcript]
  end
end

seed_bulk_feedback!(
  onboarding_loop,
  count: 30,
  questions_and_answers: {
    "What made you sign up for LoopAI?" => [
      "I was tired of low response rates on Typeform surveys, so I wanted something more conversational.",
      "A friend recommended it after complaining about feedback fatigue with our users.",
      "We needed a faster way to understand why trial users were dropping off.",
      "I liked the idea of an AI actually asking follow-up questions instead of a static form.",
      "Our old survey tool felt impersonal, so I wanted to try a chat-based approach.",
      "I saw a demo online and wanted to see if it worked as well as it looked.",
      "Honestly I was just curious how an AI-led interview compares to a normal survey.",
      "We're a small team and didn't have time to manually interview every user, so this seemed efficient."
    ],
    "Was there anything confusing during setup?" => [
      "Not really, it was pretty intuitive.",
      "A little - I wasn't sure how many questions to add at first.",
      "The slug in the share link looked random, so I double checked it wasn't broken.",
      "I had to look twice to find where to edit my questions after creating the loop.",
      "Nothing major, just took a minute to find the share link.",
      "It was smooth, maybe just wished there were more example questions to start from."
    ],
    "What almost made you give up before finishing onboarding?" => [
      "Nothing really, it only took a few minutes.",
      "I was worried my users wouldn't bother chatting with a bot, but that wasn't an issue.",
      "I got pulled into a meeting halfway through creating my loop, but coming back was easy.",
      "Honestly nothing, it was quicker than I expected.",
      "I almost skipped it thinking it'd be complicated, but it wasn't."
    ]
  }
)

seed_bulk_feedback!(
  pricing_loop,
  count: 20,
  questions_and_answers: {
    "What's your first reaction to our pricing page?" => [
      "Clean design, but the tiers could be clearer.",
      "A bit steep for a solo founder, but understandable given what it replaces.",
      "I liked that it was simple, no hidden add-ons.",
      "Took me a second to see the difference between Pro and Team.",
      "Reasonable, roughly what I expected for this kind of tool."
    ],
    "Is there a plan that feels right for you? Why or why not?" => [
      "Pro feels right for now since I'm the only one using it.",
      "Probably Starter, I only run one loop at a time.",
      "Team, since a few of us would want access to the insights.",
      "Not yet, I'd want to try it longer before committing to a paid tier.",
      "Pro seems fair for the features I actually use."
    ],
    "What would make you more confident about upgrading?" => [
      "A short trial of the higher tier so I can compare it directly.",
      "Clearer examples of the AI summaries in action.",
      "Case studies from other founders my size.",
      "A discount for annual billing would help.",
      "Just more usage history to see if it's worth it long-term."
    ]
  }
)

seed_bulk_feedback!(
  feature_request_loop,
  count: 18,
  questions_and_answers: {
    "What's the one feature you wish LoopAI had right now?" => [
      "CSV export of transcripts.",
      "Automatic topic tagging for feedback.",
      "The ability to reopen a past conversation.",
      "Slack notifications when new feedback comes in.",
      "A way to compare feedback across two time periods side by side."
    ],
    "How are you working around not having it today?" => [
      "Copy-pasting into a spreadsheet by hand.",
      "Reading every transcript myself to spot patterns.",
      "Asking respondents to just start a new conversation.",
      "Checking the dashboard manually a few times a day.",
      "Exporting screenshots instead, which isn't great for search."
    ],
    "How would this feature change the way you use LoopAI?" => [
      "I'd trust it as our main source of truth instead of a side tool.",
      "I could spend less time triaging and more time acting on it.",
      "It would make longer-term check-ins feel continuous.",
      "I'd check in on feedback in real time instead of batching it weekly.",
      "It would make reporting to my team much faster."
    ]
  }
)

seed_bulk_feedback!(
  support_loop,
  count: 15,
  questions_and_answers: {
    "How would you rate your recent support experience?" => [
      "Pretty good, the response came back within a couple hours.",
      "It was fine, though it took a few back-and-forths.",
      "Great, way faster than I expected.",
      "Okay, but I had to repeat my issue more than once.",
      "Really solid, they clearly understood the problem right away."
    ],
    "Was your issue fully resolved?" => [
      "Yes, same day.",
      "Eventually yes, but it took about three days.",
      "Yes, and they followed up afterward to confirm it stuck.",
      "Mostly, there's a small edge case that still happens occasionally.",
      "Yes, no complaints."
    ],
    "What could we have done better?" => [
      "A status page so I didn't have to ask if it was a known issue.",
      "More proactive updates while it was being looked into.",
      "Nothing really, it was a smooth process.",
      "Faster first response, the wait was the only rough part.",
      "Confirming the fix with a follow-up message instead of leaving me to check myself."
    ]
  }
)
