# Analyze tab visual refresh

## Problem

The Analyze page (`/analyze`, both "All loops" and "Per-loop overview" tabs) was left behind by the chart restyle in commit `29eb48e` ("new diagram layout"), which gave `.analysis-card` a modern rounded/shadowed look (`$radius-lg`, `$shadow-card`) but only touched the chart card and insight panel. The stat row and filter dropdowns still look like default Bootstrap: a plain `<dl>` list with no card treatment, and square-cornered `form-select`s. The result is visually inconsistent — one card on the page looks modern, the controls around it don't.

Reference: a mockup dashboard (rounded floating white stat cards, soft pill-shaped nothing-to-do-with-selects-but-similar filter affordances, purple/indigo accent) was supplied as the target aesthetic. This repo already has a matching accent token (`$color-accent: #4f46e5`) and radius/shadow tokens (`$radius-lg`, `$radius-pill`, `$shadow-card`) — this is a matter of applying existing tokens more consistently, not introducing a new visual language.

## Goal

Bring the stat row and every filter control on the Analyze page up to the same rounded, modern, "floating card" aesthetic already established by `.analysis-card`, so the whole page reads as one consistent system.

## Scope

**In scope:** `/analyze` only — both "All loops" and "Per-loop overview" tabs. Specifically:
- The 4-stat row on the per-loop tab (Responses / Themes found / Feature requests / Overall sentiment)
- All `<select>` filter controls on both tabs (Date range, Status, Sort, Data view, Chart type, per-loop picker) and the adjoining custom-date-range `<input type="date">` + Apply button

**Out of scope:**
- The home Dashboard page (similar stat-tile pattern, but explicitly deferred — a follow-up once this pattern is proven here)
- `.analysis-card`-based components that already got the rounded/shadowed treatment in `29eb48e` (chart card, insight panel, theme cards, feature-request cards, response cards) — no structural changes, they just need to sit consistently next to the redone stat tiles/selects
- The "All loops" table, empty states, transcript rendering — untouched

## Design

### 1. Stat tiles

Replace the current `<dl class="analysis-stat-row">` (plain label-over-number pairs, no background/border) with four individual floating cards, one per stat, in a flex row that wraps on narrow viewports.

Each tile:
- Same visual language as `.analysis-card` (`$radius-lg`, `$shadow-card`, `var(--color-surface)` background, `var(--color-border-subtle)` border) but smaller padding since it holds less content
- Uppercase, muted label on top (reusing the existing `dt` styling: `$font-size-sm`, `var(--color-text-muted)`)
- Large bold value below (reusing the existing `dd` styling: `$font-size-2xl`, `700` weight) — except the "Overall sentiment" tile, which renders the existing `sentiment_badge` pill instead of a plain number, matching current behavior
- **No sparklines.** Only "Responses" has real per-day history, and that's already charted immediately below this row — adding a fabricated or redundant sparkline to the other three stats (which have no time-series data at all) would misrepresent them as trending metrics they aren't.

Markup change is confined to `app/views/analyze/_stat_row.html.erb` (rewritten from a `<dl>` to a flex row of 4 card `<div>`s, values unchanged). Styling: replace `.analysis-stat-row` in `_analysis.scss` with a new `.analysis-stat-tile` rule; the `dt`/`dd` typography rules carry over unchanged (still target `dt`/`dd` inside the new markup, or get renamed to plain classes if the markup drops the `<dl>` — implementation's call, behavior is identical either way).

### 2. Filter selects

New `.analysis-select` class applied to every `form-select` on the Analyze page (Date range ×2, Status, Sort, Data view, Chart type, per-loop picker), plus the adjoining custom-range `<input type="date">` and "Apply" button:
- Fully rounded: `border-radius: $radius-pill`
- Filled, borderless look: `background: var(--color-surface-subtle)` (or `--color-background-muted`, implementation's call for best contrast against the page background), `border: none` (or a barely-visible border if Bootstrap's native select arrow rendering needs it to look intentional — implementation's call)
- Otherwise inherits Bootstrap's `form-select` sizing/behavior (padding, caret icon, focus ring) — this is a shape/surface change, not a rebuild of the control

This is purely additive CSS (`.analysis-select` alongside the existing `form-select` class) plus adding that class to the `<select>`/`<input>`/`<button>` tags already in `show.html.erb` — no JS or Stimulus controller changes, since `range_filter_controller.js` targets these elements by `data-range-filter-target`, not by class.

### 3. Everything else

No changes. `.analysis-card` and everything built on it (chart card, insight panel, theme/feature-request/response cards, empty states, the table) already match the target look after `29eb48e`.

## Testing

This is a pure visual/CSS + markup change with no new business logic, JS behavior, or data flow — nothing here is unit-testable in a way that adds signal. Verification is visual: run `bin/dev`, view `/analyze` (all-loops tab, per-loop tab, both with and without an `insight` present, and the empty-loop state) in a browser, confirm:
- Stat tiles render as 4 separate rounded cards, sentiment tile still shows its badge
- All filter selects (including per-loop picker and custom date range fields) are pill-shaped with the filled background
- No regressions to `range_filter_controller.js` behavior (toggling custom range fields, submitting on change)
- `bin/rubocop` stays clean (SCSS isn't linted by rubocop, but the `.erb` changes are in scope)
