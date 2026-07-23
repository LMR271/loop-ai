# Patterns (themes) & feature request tiles redesign

Date: 2026-07-23

## Problem

The Analyze page's "Themes" section (renders `_theme.html.erb`) and "Feature requests" section
(renders `_feature_request.html.erb`) are plain, always-expanded, single-column cards. The
section name "Themes" reads as too technical for the average user, quotes are shown in full even
when a theme has many of them, and there's no way to tell which specific interview a quote came
from.

## Goals

- Rename the "Themes" headline to "Patterns" (subtitle text is unchanged).
- Make each tile visually bolder/more modern: bigger, bolder title; rounded corners and shadow
  consistent with the rest of the Analyze page (`.analysis-card`).
- Lay tiles out in a 2-column grid on desktop (1 column on narrow screens), for both Themes and
  Feature requests.
- Make each tile collapsible: title, sentiment badge, mention count, and description always
  visible; quotes hidden until expanded.
- Tag each quote with which interview it came from ("Interview #N") and that interview's own
  sentiment, and let that tag jump to the interview's full transcript in "Every response".
- Apply the same tile treatment (grid, collapsible, quote tagging) to Feature requests, for visual
  consistency across the page.

## Non-goals

- No change to the underlying LLM pipeline, `Insight`/`Theme`/`FeatureRequest`/`Quote` models, or
  how themes/feature requests are generated.
- No change to the "Every response" list's own layout, beyond adding an anchor id to each card.
- No new JavaScript/Stimulus controller.

## Design

### Headline & copy

`show.html.erb`'s "Themes" `<h3>` becomes "Patterns". The subtitle paragraph directly below it
("Patterns that came up across multiple interviews — where to focus.") is left exactly as-is per
user request, even though it now repeats the headline word — this is an intentional, approved
tradeoff, not an oversight. The "Feature requests" headline and its subtitle are unchanged.

### Expand/collapse: native `<details>`/`<summary>`

Both `_theme.html.erb` and `_feature_request.html.erb` are restructured around a top-level
`<details class="analysis-card analysis-tile">` element, matching the existing
"View full transcript" pattern already used in `show.html.erb`'s feedback list (`<details>` /
`<summary>`, no JS). This means:

- No new Stimulus controller.
- Each tile's open/closed state is independent (browser-native `<details>` behavior).
- Collapsed by default (no `open` attribute).

`<summary>` contains everything that must stay visible when collapsed: the title/badge row (bold
title, sentiment badge, mention count badge, chevron) **and** the description paragraph beneath
it. Native `<details>` only ever hides content that lives outside `<summary>`, so the description
has to be inside it, not in the body — putting it in the body would hide it until expanded, which
contradicts the approved design ("description... always shown"). This means clicking anywhere on
the description also toggles the tile, which is an acceptable side effect of using the native
element (same click-to-toggle affordance, just a slightly larger hit area). The chevron is pure
CSS: hide the native disclosure triangle (`summary::-webkit-details-marker { display: none }`,
`summary { list-style: none }`) and add a `::after` chevron icon that rotates 180° when the parent
is `[open]`.

The tile body (inside `<details>`, after `<summary>`) contains only the quote list — the part that
stays hidden until expanded.

Note: `FeatureRequest` has no `sentiment` or `mention_count` column (only `Theme` does — see
`app/models/theme.rb` vs `app/models/feature_request.rb`), so the feature-request tile's
`<summary>` row omits the sentiment/count badges that the theme tile shows; everything else
(bold title, chevron, grid, collapsible quotes, per-quote interview tag) is shared.

### Grid layout

Replace `<div class="d-flex flex-column gap-2">` (in `show.html.erb`, wrapping both the theme and
feature-request `render partial:` collection calls) with a 2-column CSS grid:
`.analysis-tile-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: $space-4; }`,
collapsing to `grid-template-columns: 1fr` under Bootstrap's `md` breakpoint. Same class used for
both sections.

### Per-quote interview tag

Each quote currently renders as a bare `<blockquote>`. It gains a small footer line below the
quote text:

```
"quote text..."
Interview #3 · [sentiment badge for that feedback]
```

- **Numbering**: computed once in `AnalyzeController#load_per_loop_data` (not range-filtered —
  the range picker only affects "Every response"/the chart, and a quote must always resolve to a
  stable number regardless of which range is currently selected):
  `@interview_numbers = @loop.feedbacks.order(:created_at).ids.each_with_index.to_h { |id, i| [id, i + 1] }`.
  Passed to the theme/feature_request partials as an extra local on the collection `render` calls
  (Rails supports mixing `locals:` with `collection:`).
- **Sentiment**: `quote.feedback.sentiment`, rendered with the existing `sentiment_badge` helper
  (already handles `nil` by rendering nothing).
- **Link target**: because "Every response" (`@feedbacks`) is filtered by the page's date-range
  picker (default 30 days) and a quote's source interview can fall outside that window, the tag's
  `href` doesn't just append `#feedback-<id>` to the current URL — it rebuilds the analyze URL
  with `range: "custom"`, `from`/`to` both set to `quote.feedback.created_at.to_date`, guaranteeing
  that interview is included in "Every response" wherever the link is clicked from. Clicking a tag
  therefore silently changes the visible range to that interview's day; this was called out and
  approved as the right tradeoff over a dead link.
- Each response card in "Every response" (`show.html.erb`, the `@feedbacks.each` block) gains
  `id="feedback-<%= feedback.id %>"` so the link has somewhere to land.

### Styling

New rules added to `app/assets/stylesheets/pages/_analysis.scss`:

- `.analysis-tile-grid` (grid container, described above).
- `.analysis-tile` (the `<details>` element) — reuses `.analysis-card`'s existing
  background/border/radius/shadow; summary padding/typography for the bold title; the CSS-only
  chevron (`::after`, rotated via `[open] summary::after`).
- `.analysis-quote-tag` — small muted row under each blockquote holding the interview link +
  sentiment badge.

No changes to `config/_design_tokens.scss` or `config/_colors.scss` — all new rules consume
existing `$space-*`/`$radius-*`/`$shadow-*` tokens and `--color-*` custom properties, per the
project's existing convention of preferring those over bespoke values.

## Testing

- Existing analyze system/controller tests should keep passing unchanged (no route/controller
  behavior changes besides the new `@interview_numbers` computation).
- Manually verify in the browser: tiles collapse/expand independently, grid is 2-column on desktop
  and 1-column on mobile width, an interview tag jumps to the right feedback card and its date
  range covers it, sentiment badges render (and don't render for `nil`).
