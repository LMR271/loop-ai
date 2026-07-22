# Analyse page revision — design

**Date:** 2026-07-21
**Branch:** `feature/lennart-analysis-revision`
**Status:** approved (design), pending implementation plan

## Problem

Three user-reported problems with the Analyse page's per-loop view:

1. **The Insight never updates on Refresh.** `AnalyseController#refresh` enqueues `AnalyzeLoopJob.perform_later` and immediately redirects. The page re-renders the *old* insight while the job finishes seconds later in the background. There is no spinner, polling, or auto-reload, so the user never witnesses the update. (The DB does update — verified: `perform_now` advanced the insight's `generated_at`.)

2. **A real interview shows no themes / feature requests — just a summarized transcript.** `app/views/analyse/show.html.erb` renders each feedback's `title`, `summary`, `transcript`, and `sentiment_rationale`, but **never renders `extracted_points`**. Stage 1 does extract the respondent's themes/requests; the view simply has no code to show them per-interview. They only ever surface after a Stage-2 refresh folds them into the aggregate Insight.

3. **The page looks cheap and unintuitive.** No explanations of what each section is or what to do with it; weak empty states; the Insight is a small side panel rather than the headline.

A data smell surfaced during investigation: seeds create raw transcripts but never run Stage 1, and a `db:seed:replant` after an insight was generated leaves a stale insight (e.g. Loop #20 reports `analyzed_feedback_count=17` while only 2 feedbacks currently carry points).

## Background: the two-stage pipeline (unchanged in principle)

- **Stage 1 — per interview** (`FeedbackAnalyzer`, via `AnalyzeFeedbackJob`): one transcript → per-respondent themes/requests with verbatim quotes, written to `feedbacks.extracted_points`. Runs **automatically** when a real interview arrives (enqueued by the ElevenLabs webhook).
- **Stage 2 — per loop** (`LoopAnalyzer` → `LoopInsightWriter`, via `AnalyzeLoopJob`): clusters the `extracted_points` of every analyzed feedback into one loop-level `Insight` (overall sentiment + Themes + Feature Requests). **On-demand** — triggered by Refresh.

**Hard constraint:** Heroku kills any request that runs longer than 30 seconds. A synchronous refresh must therefore make **at most one** LLM call.

## Design

### 1. Refresh = synchronous, Stage-2-only, with a spinner

`AnalyseController#refresh` runs the rollup **inline** instead of `perform_later`:

- Call `LoopAnalyzer` + `LoopInsightWriter` directly (one LLM call, ~5–15s, safely under 30s).
- On success: redirect to the analyse page with a success flash — the fresh insight is already rendered.
- On `LlmClient::Error`: rescue and redirect with an **error flash** (no more silent failure).
- The Refresh button enters an "Analyzing…" disabled/spinner state on submit (Turbo's `aria-busy` on the submitting button + minimal CSS; a tiny Stimulus controller only if `aria-busy` styling proves insufficient).

Refresh deliberately does **not** re-run Stage 1 on each transcript — that would be N LLM calls and blow the 30s limit. Real interviews already get Stage 1 auto-enqueued by the webhook, so their points exist by refresh time.

`AnalyzeLoopJob` stays (used by the backfill nudge path and any future async trigger); the shared rollup logic lives in `LoopAnalyzer`/`LoopInsightWriter`, so calling them directly from the controller and from the job is the same code path.

### 2. Title + summary come from ElevenLabs (free); Stage 1 LLM does extraction only

Verified against the real payload fixture: `data.analysis.call_summary_title` and `data.analysis.transcript_summary` are populated by default.

- `ElevenLabsWebhookPayload` gains `summary_title` (→ `feedbacks.title`) and `transcript_summary` (→ `feedbacks.summary`) accessors, following the existing "all payload-shape knowledge lives here" convention and degrading to `nil` on an unexpected shape.
- `ElevenLabsWebhooksController#feedback_attributes` populates `title`/`summary` from those at ingestion — free, instant, LLM-free; the summary is visible the moment the interview lands.
- `FeedbackAnalyzer`'s prompt + schema are reduced to **extraction only** (`points`: themes/requests with verbatim quotes). It writes only `extracted_points`. Smaller prompt → cheaper + faster.
  - **Fallback:** if a feedback reaches Stage 1 with a blank `title` or `summary` (e.g. an old agent that sent none), `FeedbackAnalyzer` leaves them as-is; the view already falls back to rendering the raw transcript when `summary` is blank. We do not re-add title/summary generation to the LLM path.

### 3. Model + latency

`gpt-5-mini` is a reasoning model; latency is dominated by reasoning tokens, not output. In `LlmClient`:

- Add `reasoning_effort` to the request body to cut latency (target `"low"`, or `"minimal"` if the API accepts it for this model).
- Make both configurable via ENV so the model can be tuned without a code change:
  - `MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5-mini")`
  - `REASONING_EFFORT = ENV.fetch("OPENAI_REASONING_EFFORT", "low")`
- **Verify against the live API before committing.** The request shape is load-bearing (an unsupported param 400s). If `gpt-5-mini` rejects `reasoning_effort` in Chat Completions, fall back to omitting it and document the finding; do not ship a request that 400s.

### 4. Backfill nudge for stragglers

Stage 2 skips any feedback with empty `extracted_points`. When a loop has such stragglers (seeded feedback, or a real one whose Stage-1 job errored), surface it:

- `Loop#feedbacks_pending_extraction` — feedbacks whose `extracted_points` is empty (`{}` / no `"points"`).
- The Insight panel shows a nudge when any exist: **"N responses haven't been analyzed yet"** + an **"Analyze them"** button.
- The button posts to a new `AnalyseController#backfill` action (`POST /analyse/:slug/backfill`) that enqueues `AnalyzeFeedbackJob.perform_later` for **each** pending feedback (async — safe against the 30s timeout) and redirects with a "Analyzing N responses in the background — Refresh when it's done" flash.
- Two honest steps: Analyze (async Stage 1 backfill) → Refresh (sync Stage 2 rollup). The nudge only appears when something is actually pending.

### 5. Per-loop view redesign — a guided story

Restructure the `per_loop` tab of `show.html.erb` top-to-bottom, each section with a one-line plain-language explainer and a friendly empty state:

1. **Insight hero** (promoted from side panel to a headline card): overall sentiment badge + narrative summary + `analyzed / new` counts + Refresh button + backfill nudge. Explainer: what the insight is and that Refresh regenerates it.
2. **Themes** — intro sentence ("Patterns that came up across interviews"). Empty state: "No themes yet — collect a few interviews, then Refresh."
3. **Feature requests** — intro sentence ("Specific things respondents asked for"). Same empty-state treatment.
4. **Trends** — the existing volume/day-of-week/cumulative chart, now clearly a secondary "how much feedback, over time" section.
5. **Feedback list** — each card gains small **theme / request chips** rendered from `extracted_points`, so a single respondent's suggestion is visible immediately, independent of aggregation. Keep title/summary/transcript/sentiment_rationale.

Styling stays within Bootstrap 5.3 utilities + existing SCSS conventions (prefer `-subtle`/`-emphasis` pairings; reuse `sentiment_badge`). The `all_loops` tab is left as-is except for shared style consistency.

### 6. Seeds

Update `db/seeds.rb` so the demo shows the feature working:

- Seeded feedback carries a realistic `title`, `summary`, and `extracted_points` (`{"points" => [...]}` with theme/request entries and verbatim-looking quotes).
- Each loop with feedback gets a consistent `Insight` (+ `Theme`s, `FeatureRequest`s, `Quote`s) whose `analyzed_feedback_count` matches the number of analyzed feedbacks — no stale mismatch after `db:seed:replant`.
- Remains idempotent (replant-safe).

## Out of scope

- Auto-triggering Stage 2 on new feedback (stays on-demand by design).
- Polling/websocket live updates (synchronous Refresh makes them unnecessary).
- Changes to the respondent flow, webhook auth, or the `all_loops` tab's data logic.
- `respondent_email` capture, audio, agent re-sync (pre-existing deferred items).

## Testing

- **Controller:** `refresh` runs the rollup and renders the updated insight on success; flashes an error on `LlmClient::Error` (stub `LlmClient` via `stub_instance_method`); `backfill` enqueues one `AnalyzeFeedbackJob` per pending feedback and none for already-analyzed ones.
- **Payload:** `ElevenLabsWebhookPayload#summary_title` / `#transcript_summary` read the fixture correctly and degrade to `nil` on a malformed body.
- **Webhook:** ingestion writes `title`/`summary` from the payload.
- **FeedbackAnalyzer:** writes `extracted_points` only; leaves a pre-set title/summary untouched.
- **LlmClient:** request body includes the configured model + `reasoning_effort`; ENV overrides take effect.
- **Model:** `Loop#feedbacks_pending_extraction` returns only empty-points feedbacks.
- **View:** per-feedback chips render from `extracted_points`; sections show their empty states with zero data.
- Run `bin/ci` (note the known-stale `PagesControllerTest` red on master — confirm any failure is ours).

## Verification

- Live smoke: record/seed a feedback → confirm title/summary populate without an LLM call; run Stage 1 → confirm `extracted_points`; click Refresh → confirm the insight regenerates within the 30s budget and the page shows it; confirm `reasoning_effort` measurably reduces latency vs. the current default.
