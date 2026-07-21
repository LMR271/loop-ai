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

# ---------------------------------------------------------------------------
# Analysis-layer seeding (sentiment, per-feedback summaries, and the
# Insight -> Theme/FeatureRequest -> Quote tree). These write the same records
# the live LLM pipeline (FeedbackAnalyzer / LoopInsightWriter) would produce,
# so the Analyze dashboard looks populated without any OpenAI calls.
# ---------------------------------------------------------------------------

# Expands a {sentiment => weight} hash into a weighted pool and samples it, so a
# loop's feedback leans the way its overall_sentiment claims (e.g. Support skews
# positive) instead of being uniformly random.
def weighted_sentiment(distribution)
  distribution.flat_map { |value, weight| [value] * weight }.sample
end

# Only fills blank sentiments, so a plain re-run of db:seed never reshuffles
# scores that curated annotation may have already set.
def assign_sentiments!(loop_record, distribution)
  loop_record.feedbacks.where(sentiment: nil).find_each do |feedback|
    feedback.update!(sentiment: weighted_sentiment(distribution))
  end
end

# Hand-written feedbacks are located by a verbatim snippet unique to their
# transcript, since they share nil emails with bulk feedback and can't be looked
# up by respondent_email alone.
def find_seed_feedback(loop_record, anchor)
  loop_record.feedbacks.where("transcript LIKE ?", "%#{anchor}%").first
end

def annotate_feedback!(loop_record, annotation)
  feedback = find_seed_feedback(loop_record, annotation[:anchor])
  return unless feedback && feedback.summary.blank?

  feedback.update!(
    title: annotation[:title],
    summary: annotation[:summary],
    sentiment: annotation[:sentiment],
    sentiment_rationale: annotation[:sentiment_rationale],
    extracted_points: { "points" => annotation[:points].map { |point| point.transform_keys(&:to_s) } }
  )
end

def attach_quotes!(quotable, loop_record, quotes)
  Array(quotes).each do |quote|
    feedback = find_seed_feedback(loop_record, quote[:anchor])
    next unless feedback

    quotable.quotes.create!(feedback: feedback, text: quote[:text])
  end
end

def build_insight!(loop_record, spec)
  return if loop_record.insight.present?

  insight = loop_record.create_insight!(
    summary: spec[:summary],
    overall_sentiment: spec[:overall_sentiment],
    analyzed_feedback_count: loop_record.feedbacks.count,
    generated_at: Time.current
  )

  Array(spec[:themes]).each do |theme_spec|
    theme = insight.themes.create!(theme_spec.slice(:title, :description, :sentiment, :mention_count))
    attach_quotes!(theme, loop_record, theme_spec[:quotes])
  end

  Array(spec[:feature_requests]).each do |request_spec|
    request = insight.feature_requests.create!(
      request_spec.slice(:title, :description, :status, :github_issue_url)
    )
    attach_quotes!(request, loop_record, request_spec[:quotes])
  end
end

founder = User.find_or_create_by!(email: "founder@loopai.dev") do |user|
  user.name = "Founder"
  user.password = "password123"
  user.password_confirmation = "password123"
end

onboarding_loop = Loop.find_or_create_by!(user: founder, organization: founder.organization, name: "Onboarding Pulse") do |loop_record|
  loop_record.description = "How new users feel in their first week."
  # Seeds never provision a real ElevenLabs agent, so a loop must not be `active`
  # (active without an agent_id wedges the respondent flow and the activate guard).
  # `closed` is coherent for a loop that already holds feedback, and can still be
  # activated later to provision a live agent.
  loop_record.status = 2
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

pricing_loop = Loop.find_or_create_by!(user: founder, organization: founder.organization, name: "Pricing Page Feedback") do |loop_record|
  loop_record.description = "Understanding hesitation around the new pricing tiers."
  loop_record.status = 2 # closed — see Onboarding note; seeds never mark a loop active.
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

churn_loop = Loop.find_or_create_by!(user: founder, organization: founder.organization, name: "Churned Users Check-in") do |loop_record|
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

feature_request_loop = Loop.find_or_create_by!(user: founder, organization: founder.organization, name: "Feature Request Roundup") do |loop_record|
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

support_loop = Loop.find_or_create_by!(user: founder, organization: founder.organization, name: "Support Experience Review") do |loop_record|
  loop_record.description = "Checking in after a support ticket to see how it went."
  loop_record.status = 2 # closed — see Onboarding note; seeds never mark a loop active.
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

# ---------------------------------------------------------------------------
# Populate the analysis layer. Each loop leans a way that matches its Insight's
# overall_sentiment; quotes cite verbatim snippets from real seeded transcripts.
# ---------------------------------------------------------------------------

assign_sentiments!(onboarding_loop, { "excited" => 4, "positive" => 4, "neutral" => 2, "frustrated" => 1 })
assign_sentiments!(pricing_loop,    { "excited" => 1, "positive" => 3, "neutral" => 4, "frustrated" => 2 })
assign_sentiments!(feature_request_loop, { "excited" => 2, "positive" => 5, "neutral" => 3, "frustrated" => 1 })
assign_sentiments!(support_loop,    { "excited" => 3, "positive" => 5, "neutral" => 2, "frustrated" => 1, "negative" => 1 })

[
  [onboarding_loop, {
    anchor: "drowning in Google Form responses",
    title: "Switched from low-response form tools",
    summary: "A SaaS founder signed up because survey forms weren't getting filled out, and " \
             "found the conversational format both fast to set up and more engaging for their users.",
    sentiment: "excited",
    sentiment_rationale: "Describes onboarding as a 5-minute success and reports users preferring the " \
                         "chat over forms — enthusiastic, not merely satisfied.",
    points: [
      { kind: "theme", title: "Fast setup", quote: "it took me like 5 minutes to create my first loop and share the link" },
      { kind: "theme", title: "Higher engagement than forms", quote: "Turns out they liked it more" }
    ]
  }],
  [onboarding_loop, {
    anchor: "an AI-run interview would feel",
    title: "Smooth but slightly wary of the link",
    summary: "A curious respondent had a smooth setup overall, though the random-looking slug in the " \
             "share URL made them briefly unsure the link was legitimate.",
    sentiment: "positive",
    sentiment_rationale: "Calls it a smooth experience overall but flags mild hesitation about the URL — " \
                         "positive with a small caveat.",
    points: [
      { kind: "theme", title: "Share link looks untrusted", quote: "I wasn't sure if the link was legit at first" }
    ]
  }],
  [onboarding_loop, {
    anchor: "five-point scales",
    title: "Wanted conversation over surveys",
    summary: "This user chose LoopAI to escape five-point-scale surveys, but didn't realise custom " \
             "questions were editable until exploring the dashboard.",
    sentiment: "positive",
    sentiment_rationale: "Happy with the conversational premise; the only friction was discoverability of " \
                         "question editing.",
    points: [
      { kind: "theme", title: "Editing questions is hard to find", quote: "I didn't realize I could add my own questions until I poked around the dashboard" }
    ]
  }],

  [pricing_loop, {
    anchor: "different between Pro and Team",
    title: "Wants a trial to justify Team",
    summary: "Found the pricing page clean but had to scroll to see how Pro and Team differ; would upgrade " \
             "if a short trial of Team features helped convince their cofounder.",
    sentiment: "neutral",
    sentiment_rationale: "Balanced — praises the design but names a real blocker (unclear tier differences) " \
                         "and a condition for upgrading.",
    points: [
      { kind: "theme", title: "Tier differences unclear", quote: "I had to scroll to find what's actually different between Pro and Team" },
      { kind: "request", title: "Trial of Team features", quote: "A short trial of Team features would help me convince my cofounder" }
    ]
  }],
  [pricing_loop, {
    anchor: "steep for a solo founder honestly",
    title: "Price feels steep solo",
    summary: "A solo founder finds the pricing steep but understands the value; would feel more confident " \
             "with clearer examples of the AI summaries rather than a feature list.",
    sentiment: "frustrated",
    sentiment_rationale: "Leads with 'a bit steep for a solo founder' and asks for proof of value — priced-out " \
                         "hesitation, not outright rejection.",
    points: [
      { kind: "theme", title: "Steep for solo founders", quote: "A bit steep for a solo founder honestly" },
      { kind: "request", title: "Show the AI summaries in action", quote: "Clearer examples of the AI summaries in action, not just a feature list" }
    ]
  }],

  [feature_request_loop, {
    anchor: "Native export to CSV",
    title: "Needs CSV export as source of truth",
    summary: "Wants native CSV export to pull transcripts into their own analytics stack; today they " \
             "copy-paste manually and won't treat LoopAI as the source of truth until export exists.",
    sentiment: "positive",
    sentiment_rationale: "Engaged and invested — the request is framed as what would deepen their reliance, " \
                         "not a complaint.",
    points: [
      { kind: "request", title: "CSV export", quote: "Native export to CSV. I want to pull transcripts into our own analytics stack" },
      { kind: "theme", title: "Manual workaround is slow", quote: "Copy-pasting transcripts into a spreadsheet manually, which is slow and error-prone" }
    ]
  }],
  [feature_request_loop, {
    anchor: "Tagging or categorizing feedback automatically",
    title: "Wants automatic topic tagging",
    summary: "Reads every transcript by hand to group themes and wants automatic topic tagging so they can " \
             "spend less time triaging and more acting on feedback.",
    sentiment: "positive",
    sentiment_rationale: "Constructive request grounded in a concrete time cost; tone is eager rather than " \
                         "negative.",
    points: [
      { kind: "request", title: "Automatic topic tagging", quote: "Tagging or categorizing feedback automatically by topic" }
    ]
  }],
  [feature_request_loop, {
    anchor: "reopen a conversation if a respondent wants to add more",
    title: "Wants to reopen conversations",
    summary: "Would like to reopen a past conversation when a respondent has more to add, turning one-off " \
             "interviews into continuous, longer-term check-ins.",
    sentiment: "neutral",
    sentiment_rationale: "Matter-of-fact feature request describing a workflow gap, without strong positive " \
                         "or negative affect.",
    points: [
      { kind: "request", title: "Reopen past conversations", quote: "The ability to reopen a conversation if a respondent wants to add more later" }
    ]
  }],

  [support_loop, {
    anchor: "slug redirect bug I reported",
    title: "Fast fix, wants a status page",
    summary: "Got a same-day fix for the slug redirect bug and rated support highly; the only ask was a " \
             "status page to avoid having to ask whether an issue is already known.",
    sentiment: "positive",
    sentiment_rationale: "Praises fast turnaround and full resolution; the suggestion is an enhancement, not " \
                         "a grievance.",
    points: [
      { kind: "theme", title: "Fast resolution", quote: "the slug redirect bug I reported got fixed the same day" },
      { kind: "request", title: "Status page", quote: "Maybe a status page so I didn't have to ask if it was a known issue" }
    ]
  }],
  [support_loop, {
    anchor: "back-and-forths to get to the actual fix",
    title: "Resolved but slow and repetitive",
    summary: "Issue was resolved but only after several back-and-forths over about three days; wants more " \
             "proactive updates while a problem is being investigated.",
    sentiment: "frustrated",
    sentiment_rationale: "Resolution came eventually, but the respondent stresses the delay and repetition — " \
                         "mild frustration with the process.",
    points: [
      { kind: "theme", title: "Slow, repetitive resolution", quote: "it took a couple of back-and-forths to get to the actual fix" },
      { kind: "request", title: "Proactive status updates", quote: "A bit more proactive updates while it was being looked into" }
    ]
  }]
].each { |loop_record, annotation| annotate_feedback!(loop_record, annotation) }

build_insight!(onboarding_loop, {
  overall_sentiment: "excited",
  summary: "New users describe onboarding as fast and refreshingly conversational, and are pleasantly " \
           "surprised that respondents prefer chatting over filling out forms. The main friction is " \
           "discoverability — the share link looks untrusted and question editing is hard to find.",
  themes: [
    {
      title: "Fast, frictionless setup",
      description: "Users repeatedly note how quickly they got their first loop live and shared.",
      sentiment: "excited",
      mention_count: 3,
      quotes: [
        { anchor: "drowning in Google Form responses", text: "it took me like 5 minutes to create my first loop and share the link" }
      ]
    },
    {
      title: "More engaging than forms",
      description: "Respondents preferred the conversational format over static surveys, easing a key worry.",
      sentiment: "positive",
      mention_count: 2,
      quotes: [
        { anchor: "drowning in Google Form responses", text: "Turns out they liked it more" },
        { anchor: "five-point scales", text: "I wanted feedback that felt like a real conversation instead of a survey with five-point scales" }
      ]
    },
    {
      title: "Discoverability friction",
      description: "The random-looking share slug reads as untrustworthy and question editing is hard to find.",
      sentiment: "neutral",
      mention_count: 2,
      quotes: [
        { anchor: "an AI-run interview would feel", text: "I wasn't sure if the link was legit at first" },
        { anchor: "five-point scales", text: "I didn't realize I could add my own questions until I poked around the dashboard" }
      ]
    }
  ],
  feature_requests: [
    {
      title: "Trust signals on the share link",
      description: "Make the respondent link clearly legitimate so users aren't nervous sharing it.",
      status: "open",
      quotes: [
        { anchor: "an AI-run interview would feel", text: "The slug in the URL looked a little random, I wasn't sure if the link was legit at first" }
      ]
    }
  ]
})

build_insight!(pricing_loop, {
  overall_sentiment: "neutral",
  summary: "Reactions to pricing are mixed. The page looks clean but the difference between Pro and Team " \
           "isn't obvious, and solo founders find it steep. The clearest path to upgrades is proof of " \
           "value — a short trial and concrete examples of the AI summaries.",
  themes: [
    {
      title: "Tier differences are unclear",
      description: "Users struggle to see what separates Pro from Team without scrolling and comparing.",
      sentiment: "neutral",
      mention_count: 2,
      quotes: [
        { anchor: "different between Pro and Team", text: "I had to scroll to find what's actually different between Pro and Team" }
      ]
    },
    {
      title: "Steep for solo founders",
      description: "Solo users feel the price is high for one seat, even while understanding the value.",
      sentiment: "frustrated",
      mention_count: 2,
      quotes: [
        { anchor: "steep for a solo founder honestly", text: "A bit steep for a solo founder honestly, but I get why given what it replaces" }
      ]
    }
  ],
  feature_requests: [
    {
      title: "Short trial of higher tiers",
      description: "Let users try Team features briefly to justify upgrading to teammates.",
      status: "planned",
      github_issue_url: "https://github.com/LMR271/loop-ai/issues/142",
      quotes: [
        { anchor: "different between Pro and Team", text: "A short trial of Team features would help me convince my cofounder" }
      ]
    },
    {
      title: "Show the AI summaries in action",
      description: "Concrete examples of generated summaries would build confidence better than a feature list.",
      status: "open",
      quotes: [
        { anchor: "steep for a solo founder honestly", text: "Clearer examples of the AI summaries in action, not just a feature list" }
      ]
    }
  ]
})

build_insight!(feature_request_loop, {
  overall_sentiment: "positive",
  summary: "Engaged users want LoopAI to become their source of truth. The strongest asks are data export " \
           "and automatic organisation of feedback, with manual copy-pasting and hand-grouping named as the " \
           "workarounds they'd happily drop.",
  themes: [
    {
      title: "Manual workarounds are painful",
      description: "Users copy-paste transcripts and hand-group themes because the tooling isn't there yet.",
      sentiment: "frustrated",
      mention_count: 2,
      quotes: [
        { anchor: "Native export to CSV", text: "Copy-pasting transcripts into a spreadsheet manually, which is slow and error-prone" },
        { anchor: "Tagging or categorizing feedback automatically", text: "Reading every transcript myself and mentally grouping the themes" }
      ]
    },
    {
      title: "Wants LoopAI as source of truth",
      description: "Users would deepen their reliance on LoopAI if the missing workflow pieces existed.",
      sentiment: "positive",
      mention_count: 2,
      quotes: [
        { anchor: "Native export to CSV", text: "I'd trust it as our source of truth instead of treating it as a side tool" }
      ]
    }
  ],
  feature_requests: [
    {
      title: "CSV / data export",
      description: "Native export so teams can pull transcripts into their own analytics stack.",
      status: "planned",
      github_issue_url: "https://github.com/LMR271/loop-ai/issues/98",
      quotes: [
        { anchor: "Native export to CSV", text: "Native export to CSV. I want to pull transcripts into our own analytics stack" }
      ]
    },
    {
      title: "Automatic topic tagging",
      description: "Categorise feedback by topic automatically to cut down triage time.",
      status: "open",
      quotes: [
        { anchor: "Tagging or categorizing feedback automatically", text: "Tagging or categorizing feedback automatically by topic" }
      ]
    },
    {
      title: "Reopen past conversations",
      description: "Let respondents add to a finished conversation so check-ins feel continuous.",
      status: "dismissed",
      quotes: [
        { anchor: "reopen a conversation if a respondent wants to add more", text: "The ability to reopen a conversation if a respondent wants to add more later" }
      ]
    }
  ]
})

build_insight!(support_loop, {
  overall_sentiment: "positive",
  summary: "Support is well regarded, with fast fixes and full resolutions in the standout cases. The " \
           "recurring ask is communication: proactive status updates during investigation and a public " \
           "status page for known issues.",
  themes: [
    {
      title: "Fast, effective fixes",
      description: "Standout cases were resolved the same day and left users confident in support.",
      sentiment: "positive",
      mention_count: 2,
      quotes: [
        { anchor: "slug redirect bug I reported", text: "the slug redirect bug I reported got fixed the same day" }
      ]
    },
    {
      title: "Communication during investigation",
      description: "Slower cases suffered from back-and-forth and a lack of proactive updates.",
      sentiment: "frustrated",
      mention_count: 2,
      quotes: [
        { anchor: "back-and-forths to get to the actual fix", text: "it took a couple of back-and-forths to get to the actual fix" }
      ]
    }
  ],
  feature_requests: [
    {
      title: "Public status page",
      description: "A status page so users can self-check known issues instead of opening a ticket.",
      status: "open",
      quotes: [
        { anchor: "slug redirect bug I reported", text: "Maybe a status page so I didn't have to ask if it was a known issue" }
      ]
    },
    {
      title: "Proactive ticket updates",
      description: "Keep users informed while an issue is being investigated rather than going quiet.",
      status: "planned",
      quotes: [
        { anchor: "back-and-forths to get to the actual fix", text: "A bit more proactive updates while it was being looked into" }
      ]
    }
  ]
})
