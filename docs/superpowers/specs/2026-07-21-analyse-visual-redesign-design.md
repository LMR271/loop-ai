# Analyse tab visual redesign — design

**Date:** 2026-07-21
**Branch:** `feature/lennart-analysis-revision`
**Status:** approved (design), pending implementation plan

## Problem

The Analyse page's structure and content were reworked by `docs/superpowers/specs/2026-07-21-analyse-page-revision-design.md` (guided-story sections, insight hero, chips, backfill nudge — already implemented, see commits `ed57964`..`c2c8fee`). What's left is the *visual* layer, reported directly by the user:

1. The interface reads as visually dated and unintentional — inconsistent card treatments, a filled-pill tab style, and no restraint on color.
2. When a loop has zero feedback, the page degrades into several small, mismatched placeholder boxes (an empty 10rem chart square, a plain "No analysis yet" sentence, a separate empty response-list box) rather than one coherent state — inconsistent with the dashboard's single centered "No loops yet" empty state.
3. A first-time user can't tell at a glance what each section means or how to act on it (is the "summary" the respondent's words or a generated digest? what's a "theme" vs. a "feature request"?).

The user pointed to ElevenLabs' own dashboard as a reference for tone: hairline borders, white surface cards, gray-label/bold-value stat rows, underlined (not filled) tabs, and small icon + one-sentence empty states scoped to the specific thing that's missing.

## Non-goals

- No changes to controller logic, data queries, chart data, or the LLM pipeline (Stage 1/2 unchanged).
- No changes to the `AnalyseHelper#sentiment_badge` mapping or values.
- Not a fix for the separately reported webhook/analysis latency issue — `reasoning_effort` was already added in `03ead73` to address a prior slowness report; the user's current complaint needs its own investigation (systematic-debugging) and is tracked as follow-up, not part of this spec.
- Not a redesign of the Dashboard, Deploy, or Team pages — the dashboard's existing empty-state pattern is used only as a *reference*, not itself modified.

## Design

### 1. Visual language: neutral cards + ElevenLabs-style tabs

- Introduce one shared card class, `.analysis-card` (`app/assets/stylesheets/pages/_analysis.scss`): white surface (`--color-surface`), 1px `--color-border`, `$radius-card`, `$space-6` padding, no shadow. Replace the current mix of ad-hoc `border rounded p-3`/`p-4` divs (`_insight_panel`, `_theme`, `_feature_request`, response cards, chart card) with this one class so every box in the tab reads as the same system.
- Replace `analysis-chart-card`/`analysis-summary-card` (currently near-duplicates of the new class) with `.analysis-card` directly; keep any card that needs a taller minimum height as a size modifier, not a separate class.
- Replace the Bootstrap `nav-tabs` pill style with underlined text tabs: active tab gets `--color-text` + a bottom border, inactive tabs are `--color-text-muted` with no border, no filled background. Scoped CSS only (`.analysis-tabs .nav-link`) — do not change `nav-tabs` globally, since other pages may use it.
- No new colors are introduced. Color stays reserved for meaning: `sentiment_badge`'s existing palette, and the existing tag/lightbulb chip tint for theme vs. request. Everything else (cards, tabs, headings, body text) uses the existing neutral tokens already defined in `_design_tokens.scss`.
- Applies to both the `per_loop` and `all_loops` tab panes, since both should look like one system even though only `per_loop` has content changes below.

### 2. Quiet stat row (Overview tab only)

A thin, borderless row above the insight card, styled as small gray labels over bold values (no card, no background) — same pattern as the reference screenshot's top strip:

```
Responses          Themes found       Feature requests    Overall sentiment
   24                    5                    3               Positive
```

- Source: `@loop.feedbacks.size` (Responses — *all* feedback, not range-filtered, since this is orientation, not a filtered chart), `@loop.insight&.themes&.size || 0`, `@loop.insight&.feature_requests&.size || 0`, `sentiment_badge(@loop.insight&.overall_sentiment)` (renders nothing if nil, consistent with existing behavior).
- Hidden entirely in the unified empty state (section 4) — there's nothing to orient around yet.
- Implemented as a small helper or partial (`_stat_row.html.erb`) taking `loop_record:`, so it stays a single well-bounded unit.

### 3. Insight card, Themes, and Feature requests — explicit first-time framing

Each section keeps its current position (insight card, then Themes, then Feature requests, unchanged from the guided-story spec) but gets clearer copy and a scoped empty state instead of a plain `alert alert-light` box:

- **Insight card**: heading becomes "Summary of all feedback" (was "What people are telling you"); subtext becomes "AI-generated from every interview transcript in this loop. Press Refresh after new responses come in." Sentiment badge, analyzed/new counts, Refresh button, and backfill nudge are unchanged.
- **Themes**: keep existing explainer ("Patterns that came up across multiple interviews — where to focus."). Empty state (loop has feedback + insight, but zero themes) becomes an icon (tag) + the existing sentence, styled as a centered mini-block inside `.analysis-card` rather than a full-width alert strip.
- **Feature requests**: keep existing explainer ("Specific things respondents asked you to build."). Same icon-scoped empty-state treatment (lightbulb icon), reusing its existing empty sentence.
- **Every response** section: explainer sentence changes to "Each interview in full. The summary above the transcript is AI-generated — the transcript itself is the respondent's own words." Each card gains a small uppercase label ("AI summary") directly above the title/summary block, before the "View full transcript" toggle, so the generated text is never mistaken for a quote.

None of these empty-state or copy changes touch controller/model code — `@loop.insight`, `.themes`, `.feature_requests`, `feedback.summary` etc. are already available in the view.

### 4. Unified empty state for a loop with zero feedback ever

When `@loop.feedbacks.empty?` (not range-filtered — the loop has *never* received a response), the entire `per_loop` tab body collapses into one centered block, replacing the stat row, filter controls, chart, insight card, themes, feature requests, and response list:

- Icon + "No feedback yet."
- One-line hint: "Share your loop's link to start collecting responses." linking to the Deploy page for this loop (`deploy_path` — confirm route accepts a loop-scoping param, else link to `deploy_path` generally).
- Matches the visual pattern of the Dashboard's existing "No loops yet" empty state (`app/views/dashboard/index.html.erb`'s `.loops-empty-state`), reusing its typographic treatment (centered, muted text) rather than a new pattern.

This is distinct from the *zero-in-range* case (loop has feedback, just none matching the current date filter), which keeps today's per-section "nothing in this range" messages — the data structurally exists, so the filter controls and chart/list stay visible.

## Out of scope

- The `all_loops` tab's data/filtering logic — visual consistency only (section 1).
- The reported ElevenLabs webhook/analysis latency — separate investigation, not a UI concern.
- Any new illustration/icon assets beyond Font Awesome classes already used elsewhere in the app (`fa-tag`, `fa-lightbulb`, etc.) — no new icon library.

## Testing

- View/system test: a loop with zero feedback renders the single unified empty state (no chart, no stat row, no per-section boxes).
- View/system test: a loop with feedback but no insight yet renders the stat row with zero-value placeholders and the insight card's existing "no analysis yet" copy (unchanged behavior, just restyled).
- View/system test: a loop with an insight but zero themes (or zero feature requests) renders the scoped icon empty state for that section only, while the other sections with data render normally.
- Visual/manual check: `per_loop` and `all_loops` tabs both use `.analysis-card` and the underlined tab style; no Bootstrap `nav-tabs` pill styling remains on this page.
- Run `bin/rubocop` (view/CSS changes only, but confirm no stray Ruby helper offenses) and `bin/ci` (note the known pre-existing `PagesControllerTest` red on master).

## Verification

- Manually visit `/analyse/:slug` for: (a) a loop with zero feedback, (b) a loop with feedback but no insight, (c) a loop with an insight missing themes or feature requests, (d) a fully analyzed loop — confirm each renders the intended state and that color usage stays limited to sentiment badges and theme/request chip tints.
