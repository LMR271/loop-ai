# Feedback Analysis — Design

**Date:** 2026-07-20
**Status:** Approved design, pending spec review → implementation plan
**Branch:** `feature/lennart-feedback-analysis`

## Context & Goal

The Analyse tab currently only *counts* feedback — volume charts, day-of-week, cumulative — and lists raw transcripts. The `Insight` model exists but is a hollow shell: nothing writes it, nothing reads it. `Feedback` carries a `sentiment` + `sentiment_rationale` (from ElevenLabs) but no distilled analysis.

The goal is to make the Analyse tab **read insight out of the interviews**, at two grains:

1. **Per interview** — for a single `Feedback`: a narrative-style summary, a title, and the (existing) sentiment, so a user can revisit one respondent and understand them quickly.
2. **Per loop** — across *all* a loop's interviews: overall satisfaction/tone, a narrative summary of where the product is going, the recurring **themes** (with prevalence and supporting quotes), and the **feature requests** users named (with quotes) — the actionable material a dev team could turn into tasks.

**The two outcomes that matter most** (the north star for every decision below): (1) **deep insight** — understand what respondents actually felt and why, per interview and across the loop, without flattening the depth voice gives us; and (2) **potential improvements to the product** — surface the concrete opportunities the interviews imply. Those come through in two forms: **themes**, which include friction and pain points (not just neutral topics — a theme like "onboarding feels overwhelming" *is* a product-improvement signal), and **feature requests**, the explicit asks. If a change to the pipeline or UI doesn't serve one of these two outcomes, it's out of scope.

Voice is loop-ai's reason to exist: respondents elaborate on feeling and the *why* far more than they would in a text box. The analysis must **preserve that depth** (verbatim quotes, the respondent's experience arc), not flatten it into counts.

## Non-goals (explicitly deferred)

- **GitHub / task integration.** We design the data model so a `FeatureRequest` *can* later become a tracked task (it gets `status` + `github_issue_url` columns from day one), but we do not build the GitHub bridge now.
- **Narrative-analysis-as-a-method at the loop grain.** Narrative analysis fits the *per-interview* grain (each interview is one person's story); across 100 interviews the right method is thematic, so the loop grain is thematic + quantified, not a merged "story." (Confirmed with the founder; matches the qualitative-methods literature — cross-transcript coding *is* thematic analysis.)
- **Separate content-analysis pipeline.** Content analysis's quantitative payoff ("42% mentioned pricing") is folded into thematic analysis as the `mention_count` on each theme. No separate word-counting pipeline.
- **Audio, respondent-email capture, re-sync of edited prompts** — unchanged from the existing deferred list.

## Data model

Two grains plus a bridge. The loop-level summary connects to feedback only through the loop; the *actionable pieces inside it* (themes, requests) connect directly to the interviews that evidence them.

Naming principle: every column says plainly what it holds; every model that plays the same role uses the same field names. A `Theme` and a `FeatureRequest` are both "a short thing with a longer explanation," so both use `title` + `description`. Anything that counts interviews is spelled out (`mention_count`, `analyzed_feedback_count`), never abbreviated to jargon.

```
Loop
 ├── has_many :feedbacks          (one interview each — existing model)
 │     • title             (new, string)   — short headline for this interview
 │     • summary           (new, text)     — narrative summary (the respondent's experience + feeling)
 │     • sentiment         (existing)      — from ElevenLabs
 │     • sentiment_rationale (existing)
 │     • extracted_points  (new, jsonb)    — themes/requests + verbatim quotes pulled from THIS interview
 │
 └── has_one :insight             (the loop's overall analysis — existing model, rebuilt on demand)
       • summary                 (existing, text) — narrative "where is the product going" rollup
       • overall_sentiment       (new, string)    — dominant sentiment across all the loop's interviews
       • analyzed_feedback_count (new, integer)   — how many interviews this analysis covers (for the "new since" count)
       • generated_at            (new, datetime)  — when this analysis was last run
       ├── has_many :themes                       (recurring patterns across interviews)
       │     • title          (string)  — the theme, e.g. "Onboarding feels overwhelming"
       │     • description    (text)    — one-line explanation of what it means
       │     • mention_count  (integer) — how many interviews expressed this theme
       │     • sentiment      (string)  — dominant sentiment for this theme
       │     └── has_many :quotes
       └── has_many :feature_requests             (specific things users asked for)
             • title            (string)  — the request, e.g. "Add a guided walkthrough"
             • description      (text)    — one-line explanation
             • status           (integer enum, default: open) — lifecycle, for the future GitHub-task link
             • github_issue_url (string, nullable)            — set once promoted to a GitHub task (future)
             └── has_many :quotes

Quote  (the evidence link — connects a theme/request to the interviews that support it)
  • belongs_to :quotable, polymorphic: true   (a Theme or a FeatureRequest)
  • belongs_to :feedback                       (which interview this quote came from)
  • text (text)                                — the respondent's verbatim words
```

**How `Feedback` connects to the analysis** (the tree above can't draw this because it's a cross-link, not a parent-child edge). A `Feedback` reaches the loop-level analysis two ways:

```
                         ┌──────────────── extracted_points (jsonb) ─────────────────┐
                         │  raw material the clustering step reads to BUILD themes    │
   Feedback ─────────────┤                                                            ▼
 (one interview)         │                                              Theme / FeatureRequest
                         │                                                            ▲
                         └──── has_many :quotes ──►  Quote  ──belongs_to :quotable────┘
                                                       │  (persisted evidence link:
                                                       └── belongs_to :feedback ──► back to THIS interview)
```

1. **Data flow (generation time):** the feedback's `extracted_points` are consumed by the clustering step to *build* themes/requests. Not a DB association — a jsonb column read once when the analysis runs.
2. **Evidence link (persisted):** a `Quote` row ties a resulting theme/request back to the exact interview (and the verbatim words) that support it. This is the real `Feedback`↔analysis association in the database.

So `Feedback`'s associations are: `belongs_to :loop` (unchanged), `has_many :quotes`, and *through* quotes it connects to the `Theme`s and `FeatureRequest`s that cite it. `Feedback` never associates to `Insight` directly — it reaches the loop analysis through the loop (for counting) and through quotes (for evidence).

### Modeling decisions

- **`Theme` and `FeatureRequest` are separate models**, not one model with a `type`. They have different lifecycles: a theme is descriptive analysis; a feature request is an actionable item that later grows a `status` and a GitHub link.
- **`FeatureRequest`, not `Request`** — avoids collision with `ActionDispatch::Request` and reads self-documenting.
- **`Quote` is the evidence link, polymorphic** (`quotable` = Theme | FeatureRequest) so a theme and a request share one join to `Feedback` carrying the verbatim `text`. Alternative considered: two separate join tables — rejected as duplicative. If polymorphism proves awkward, splitting is a mechanical change. (Named `Quote` rather than `Citation` because "quote" is what it plainly is.)
- **`mention_count` is stored, not derived from `quotes.count`.** The clustering step may know a theme appears in 40 interviews while only keeping ~3 representative quotes — so prevalence and quote-count differ. `mention_count` is the true prevalence; `quotes` are the illustrative evidence. (This is standard thematic-analysis practice: report the count, show a few quotes.)
- **`extracted_points` (jsonb on `feedbacks`)** holds the per-interview structured output the loop rollup clusters, so Stage 2 never re-reads transcripts (see pipeline). Shape:
  ```json
  {
    "points": [
      { "kind": "theme",   "title": "…", "quote": "…verbatim…" },
      { "kind": "request", "title": "…", "quote": "…verbatim…" }
    ]
  }
  ```
- **`insights.sentiment` was already removed** earlier (wrong grain). `overall_sentiment` here is a *derived rollup* across the loop, distinct from per-conversation `Feedback#sentiment` — stored on the insight, not recomputed on every render.

### Migrations

1. `add_column :feedbacks, :title, :string`
2. `add_column :feedbacks, :summary, :text`
3. `add_column :feedbacks, :extracted_points, :jsonb, default: {}, null: false`
4. `add_column :insights, :overall_sentiment, :string`
5. `add_column :insights, :analyzed_feedback_count, :integer, default: 0, null: false`
6. `add_column :insights, :generated_at, :datetime`
7. `create_table :themes` — `insight_id` (fk), `title`, `description`, `mention_count` (int default 0), `sentiment`
8. `create_table :feature_requests` — `insight_id` (fk), `title`, `description`, `status` (int default 0), `github_issue_url`
9. `create_table :quotes` — `quotable_type`, `quotable_id`, `feedback_id` (fk), `text`; index on `[quotable_type, quotable_id]` and on `feedback_id`

> **Sequence gotcha (from CLAUDE.md):** these are all fresh `create_table`s — no `rename_table`, so no sequence-rename hazard. Confirm `grep nextval db/schema.rb` stays empty after migrating.

## The analysis pipeline

Two stages: **extract** (per interview, cheap, at ingestion) then **cluster** (per loop, on demand). The core principle — **extract, don't summarize** — is what keeps verbatim quotes and specific requests from being smoothed away.

### Stage 1 — per-feedback extraction (on ingestion)

When the webhook records a `Feedback`, enqueue `AnalyzeFeedbackJob` (Solid Queue). It calls the LLM once over that transcript and writes back:
- `title` — a short headline for the interview
- `summary` — a **narrative** summary: the respondent's experience arc and feeling (richer than ElevenLabs' free `transcript_summary`, which we capture as a cheap fallback if the LLM call fails)
- `extracted_points` — **structured extraction, not prose**: candidate themes and feature requests, each with a **verbatim quote** copied word-for-word from the transcript

`sentiment` / `sentiment_rationale` already arrive from ElevenLabs — the extraction call does **not** recompute them.

This runs once per interview and never re-runs unless the transcript changes. Because the quotes are captured verbatim here, they survive intact into the loop rollup.

**Existing feedback (backfill).** Feedback that predates this feature — seeded rows and any real interviews already ingested — has no `extracted_points`. A one-off backfill task enqueues `AnalyzeFeedbackJob` for every feedback missing an extraction; Stage 2 also treats "missing extraction" as a signal to enqueue Stage 1 first, so it never clusters over incomplete data.

**Partial failures.** If Stage 1 fails for a given interview (LLM error), that feedback keeps its ElevenLabs `sentiment` and falls back to ElevenLabs' `transcript_summary`/`call_summary_title` for `summary`/`title`, and contributes no `extracted_points`. Stage 2 simply clusters over whatever extractions exist rather than blocking on a single failure.

### Stage 2 — loop-level clustering (on demand)

When the user triggers a refresh, enqueue `AnalyzeLoopJob`. It reads the **`extracted_points` of every feedback in the loop** (never the full transcripts again) and makes one LLM call that **clusters and de-duplicates** those points into:
- `Theme` rows — each with a `title`, one-line `description`, `mention_count` (how many interviews expressed it), dominant `sentiment`, and `Quote` rows linking the supporting feedbacks + their verbatim text
- `FeatureRequest` rows — same shape, actionable
- The loop-level `Insight` — `overall_sentiment` and a narrative `summary`

The reduce step **groups**, it does not re-summarize — so the specific quotes and requests are preserved, addressing the fidelity concern head-on. Because it operates on the compact per-interview extractions (~100 × a few hundred tokens), it fits one context window comfortably regardless of interview count. (Embed-and-cluster is the fallback only if a single loop ever reaches thousands of interviews — deferred.)

### The LLM provider (swappable)

- **Model:** OpenAI **GPT-5 mini** (`$0.125 / $1.00` per 1M tokens as of 2026-07; cheap, reliable, strong structured output), via the `ruby-openai` gem.
- **Isolation:** all LLM calls go through a single service object (e.g. `FeedbackAnalyzer` / `LoopAnalyzer`) that owns the prompt, the request, structured-output parsing, and error handling. The provider is a **one-line change** — no analysis logic knows which vendor it's talking to.
- **Structured output:** use OpenAI's JSON/structured-output mode so the extraction and clustering return schema-valid JSON we can persist directly.
- **API key** via `.env` (`OPENAI_API_KEY`); must also be set as a Heroku config var for production.
- **Cost sanity:** a full 100-interview analysis is ~cents; the recurring refresh (reduce only) is a fraction of that. Cost is not a design constraint at this volume.

## Privacy — respondent transcripts leave the app

This is a **new data-sharing surface** and deserves a conscious decision. Today, respondent transcripts are treated as PII: the webhook layer deliberately never logs them, and they live only in our database. Stage 1 changes that — it sends each transcript to **OpenAI** for extraction. Points to settle before shipping:

- **OpenAI API data is not used for training by default**, and is retained only transiently for abuse monitoring — but OpenAI still becomes a **sub-processor** of respondent PII. If loop-ai has (or will have) a privacy policy or DPA with its customers, OpenAI needs to be disclosed/added as a sub-processor.
- **Send only what's needed.** The extraction call needs the transcript text; it does **not** need respondent identity. Since `respondent_email` is currently always nil this is moot today, but when email capture lands, do not send it to the LLM.
- **Redaction (future consideration).** If respondents may state personal details aloud, a redaction pass before the LLM call is a possible hardening step — deferred, but noted so it isn't forgotten.
- This is a **business/legal decision, not just a technical one** — flagging it here so it's made deliberately rather than by default.

## Generation triggers & staleness

- **Per-feedback (Stage 1):** automatic, async, on webhook ingestion. No user action.
- **Loop-level (Stage 2):** **on demand.** The user clicks **Refresh analysis** on the Analyse tab; `AnalyzeLoopJob` runs and replaces the loop's `Insight`/`Theme`/`FeatureRequest` set.
- **Staleness signal:** `insights.analyzed_feedback_count` records how many feedbacks the current analysis folded in. `loop.feedbacks.count - insight.analyzed_feedback_count` is the number of new, un-analyzed interviews.
- **Bell notification:** the navbar already has a bell button (`app/views/shared/_navbar.html.erb:21`), but it is currently a **static, inert placeholder** — no badge, no dropdown, no data source. Wiring it is net-new work: a badge showing the total un-analyzed count across the workspace's loops, and a dropdown listing loops with new responses (*"20 new responses since your last analysis"*) each linking to that loop's Analyse tab + Refresh button. The count source is the `feedbacks.count - analyzed_feedback_count` per loop, summed. This turns on-demand from a chore into a prompt (fixes on-demand's one weakness: people forgetting to refresh). **Scope note:** if wiring the bell balloons the plan, it can ship as a fast-follow — the Refresh button on the Analyse tab is the load-bearing trigger; the bell is the discoverability layer on top.

## UI — reshape the existing Analyse tab

Reuse `app/views/analyse/show.html.erb`; do not rebuild. The per-loop tab already has the exact seams:

- **The `"Summary coming soon"` card → the Insight panel.** Fill it with `overall_sentiment` (via the existing `sentiment_badge` helper) and the narrative `summary`. Add the **Refresh analysis** button + a "N new interviews since last run · generated <time> ago" line here.
- **In-progress state.** Because Stage 2 runs async, the tab has three states: *never analyzed* (empty state + "Run analysis" CTA), *analyzing…* (spinner after Refresh is pressed), and *done* (the panel + themes + requests). Use Turbo (Turbo Stream broadcast or a light poll) so the panel updates when the job finishes without a manual reload.
- **New Themes section** (below the chart row): each theme as a card/chip showing `title`, `mention_count` ("8 of 24 interviews"), a sentiment badge, and an expandable list of supporting `Quote`s (each linking to its `Feedback`).
- **New Requests section:** `FeatureRequest` list — label, description, supporting quotes, and a future-facing "Create task" affordance (inert for now).
- **Feedback cards (existing list):** lead with `title` + narrative `summary`; keep the `sentiment_badge` + `sentiment_rationale`; make the raw `transcript` collapsible ("View full transcript") so the card leads with the distilled view.
- Charts, tabs, filters, and the All-loops tab are unchanged.
- Visual treatment: brand-aligned (Bootstrap 5.3 `-subtle`/`-emphasis` semantic pairings, palette from `config/_colors.scss`), scannable, quote-forward — designed during implementation, not specified here.

## Infrastructure

This feature introduces the app's **first real background jobs** (`AnalyzeFeedbackJob`, `AnalyzeLoopJob`) and the app's **first direct outbound LLM calls** (everything else goes through ElevenLabs).

> **Worker gotcha (from CLAUDE.md):** production has **no worker dyno**, so Solid Queue currently has nothing running. `deliver_later` mail (the existing `new_feedback` alert) is already latently affected. Enabling these jobs in production requires the Solid Queue supervisor to run — set `SOLID_QUEUE_IN_PUMA` so `config/puma.rb` runs it inside the web dyno (avoiding a second dyno), or add a worker dyno. This must be part of the rollout.

## Idempotency & regeneration

- **Stage 1** is keyed to a `Feedback`; re-running overwrites that feedback's `title`/`summary`/`extracted_points`. Safe to retry.
- **Stage 2** replaces the loop's `Insight` and its `Theme`/`FeatureRequest`/`Quote` graph atomically (rebuild in a transaction). **Exception for the future:** a `FeatureRequest` promoted to a GitHub task (has a `github_issue_url`) must not be destroyed on regeneration — when that feature lands, preserve or re-link promoted requests. For now, full replace is fine since nothing is promoted yet.

## Testing strategy

- **Services** (`FeedbackAnalyzer`, `LoopAnalyzer`): stub the LLM at the HTTP seam using the repo's `stub_instance_method` helper (no mocking gem available) — feed a canned structured-output payload and assert the persisted `Feedback`/`Insight`/`Theme`/`FeatureRequest`/`Quote` rows. Never hit the real API in tests.
- **Jobs:** assert enqueue on webhook ingestion; assert the job calls the service and persists results.
- **Staleness:** unit-test the `feedbacks.count - analyzed_feedback_count` logic and the bell count.
- **Fidelity guard:** a test asserting that a known verbatim quote in a transcript survives end-to-end into a `Quote.text` (guards the extract-don't-summarize invariant).
- **View:** system/integration test that the Analyse tab renders the Insight panel, themes, requests, and per-feedback summaries, and that Refresh enqueues the job.
- Run `bin/ci` before considering done (note the pre-existing red `PagesControllerTest` baseline).

## Open questions / future work

- **GitHub task integration** — the `status` + `github_issue_url` columns exist; the bridge (create issue, sync state, preserve promoted requests across regeneration) is a follow-up feature.
- **Reduce-step model tier** — start all-GPT-5-mini; if theme-clustering quality disappoints, the reduce step alone can move to a stronger model behind the same service boundary.
- **Embed-and-cluster** — only if a single loop ever exceeds what one reduce call can hold.
- **Auto-refresh (debounced)** — if users dislike manual refresh, an at-most-hourly auto-run is a small change; on-demand is the chosen default.
