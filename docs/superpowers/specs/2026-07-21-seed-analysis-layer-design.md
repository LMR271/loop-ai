# Seed the analysis layer — design

**Date:** 2026-07-21
**Status:** Approved

## Problem

The Analyse tab is empty on a freshly seeded database. `db/seeds.rb` creates loops,
questions, and feedback transcripts, but fills **none** of the fields the Analyse UI
reads for its richer views:

- per-feedback `sentiment` + `sentiment_rationale` (the sentiment pills and the italic AI note)
- per-feedback `title` + `summary` (the headline shown above each transcript)
- the whole `Insight → Theme / FeatureRequest → Quote` tree (the insight panel plus the
  Themes and Feature requests sections)

We want seed data that makes the app feel like it already has analyzed feedback, so the
analysis features can be demoed and visually tested — **without** calling the OpenAI API.

## Approach

Bypass the LLM. Write the same records `LoopInsightWriter` / `FeedbackAnalyzer` would
produce, directly in seeds. The UI cannot tell the difference, which is the point.

All additions go at the **end** of `db/seeds.rb`, after every feedback already exists.
This ordering is mandatory: each `Quote` must reference a real `feedback_id` from its own
loop (`Quote belongs_to :feedback`, and `LoopInsightWriter`'s guard only keeps quotes
whose `feedback_id` belongs to the loop).

Decisions (confirmed with the user):

- **Coverage:** every loop that has feedback (Onboarding, Pricing, Feature Requests,
  Support) gets a complete Insight. Churned Users has no feedback and stays empty.
- **Sentiment spread:** every feedback gets a sentiment pill. Bulk records stay
  transcript-only (sentiment only); the ~10 hand-written records get the full
  title + summary + rationale + extracted_points treatment.

## Three additive passes (each idempotent)

**Pass 1 — sentiment on every feedback.** A `weighted_sentiment(distribution)` helper
picks from `Feedback::SENTIMENT_VALUES`, biased per loop so each Insight's
`overall_sentiment` is honest (Support skews positive/excited, Pricing mixed/neutral,
Feature Requests lean positive, Onboarding excited). Only fills `sentiment` when blank, so
a plain re-`db:seed` doesn't reshuffle.

**Pass 2 — rich annotation on the hand-written feedbacks.** The curated transcripts get a
hand-written `title`, `summary`, `sentiment_rationale`, and an `extracted_points` jsonb
(`{"points" => [{kind, title, quote}]}`) matching what `FeedbackAnalyzer` would write. Only
sets these when `summary` is blank.

**Pass 3 — one Insight per feedback-bearing loop, built like `LoopInsightWriter`.** A
curated spec per loop → `loop.create_insight!` (summary, overall_sentiment,
`analyzed_feedback_count: feedbacks.size`, `generated_at`) → 2-3 `themes`
(title/description/sentiment/mention_count + quotes) → 1-3 `feature_requests`
(title/description, `status` varied across the enum, one with a `github_issue_url` +
quotes). Each quote's `text` is a real snippet from one of that loop's transcripts and its
`feedback_id` is that transcript's feedback. Idempotency: `next if loop.insight.present?`.

## Data flow

```
existing: founder → loops → questions → feedbacks (handwritten + bulk)
new pass 1: every feedback  → sentiment
new pass 2: handwritten fb  → title, summary, rationale, extracted_points
new pass 3: each loop w/ fb → Insight → Themes / FeatureRequests → Quotes (→ real feedback)
```

## Out of scope

No changes to LLM services, jobs, controllers, models, or schema. Purely additive seed
content. The existing `weighted_recent_timestamp` / bulk-feedback logic is untouched.

## Verification

- `bin/rails db:seed:replant` runs clean and is re-runnable.
- Analyse tab (per-loop) for each of the four loops shows: a populated insight panel,
  Themes, Feature requests, sentiment pills on the feedback list, and title/summary on the
  hand-written cards.
- Churned Users still shows the empty state.
- `bin/rubocop` clean on `db/` (note: `db/` is excluded from rubocop, so this is a no-op —
  match surrounding seed style regardless).
