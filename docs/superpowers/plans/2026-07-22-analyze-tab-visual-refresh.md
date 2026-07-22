# Analyze Tab Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the Analyze page's stat row and filter controls up to the same rounded, shadowed "floating card" look `.analysis-card` already has (from `29eb48e`), so the whole page reads as one consistent visual system.

**Architecture:** Two independent, additive CSS/markup changes in `app/assets/stylesheets/pages/_analysis.scss` and `app/views/analyze/{_stat_row,show}.html.erb`. No JS, no controllers, no new routes, no schema changes. Existing design tokens (`$radius-lg`, `$radius-pill`, `$shadow-card`, `--color-surface`, `--color-surface-subtle`, `--color-text-muted`) are reused, not redefined.

**Tech Stack:** Rails 8.1 views (ERB), Bootstrap 5.3 (`form-select`), SCSS via `sassc-rails`, importmap/Stimulus (untouched by this work — `range_filter_controller.js` targets elements by `data-range-filter-target`, not by CSS class, so it keeps working unmodified).

## Global Constraints

- Scope is `/analyze` only (both "All loops" and "Per-loop overview" tabs). Do not touch the home Dashboard.
- No sparklines on any stat tile.
- No changes to `.analysis-card`-based components that already got the rounded/shadowed treatment in `29eb48e` (chart card, insight panel, theme/feature-request/response cards).
- No changes to `range_filter_controller.js` or any `data-range-filter-target`/`data-action` attributes — only add CSS classes.
- This is a pure visual/markup change with no unit-testable logic; verification is visual (`bin/dev` + browser), plus `bin/rubocop` staying clean.

---

### Task 1: Stat tiles — 4 floating cards instead of a plain `<dl>` row

**Files:**
- Modify: `app/views/analyze/_stat_row.html.erb` (currently a `<dl class="analysis-stat-row">` with 4 `dt`/`dd` pairs)
- Modify: `app/assets/stylesheets/pages/_analysis.scss:62-80` (the `.analysis-stat-row`, `.analysis-stat-row dt`, `.analysis-stat-row dd` rules)

**Interfaces:**
- Consumes: `loop_record.feedbacks.size`, `loop_record.insight&.themes&.size`, `loop_record.insight&.feature_requests&.size`, `sentiment_badge(loop_record.insight&.overall_sentiment)` (existing `AnalyzeHelper#sentiment_badge`, unchanged) — same data already used in the current partial, no new methods.
- Produces: new CSS class `.analysis-stat-tile` (and child selectors `.analysis-stat-tile__label`, `.analysis-stat-tile__value`) available for the markup below. Nothing else depends on this class yet.

- [ ] **Step 1: Replace the `<dl>` markup in `_stat_row.html.erb` with 4 card divs**

```erb
<div class="analysis-stat-tiles mb-4">
  <div class="analysis-stat-tile">
    <p class="analysis-stat-tile__label">Responses</p>
    <p class="analysis-stat-tile__value"><%= loop_record.feedbacks.size %></p>
  </div>
  <div class="analysis-stat-tile">
    <p class="analysis-stat-tile__label">Themes found</p>
    <p class="analysis-stat-tile__value"><%= loop_record.insight&.themes&.size || 0 %></p>
  </div>
  <div class="analysis-stat-tile">
    <p class="analysis-stat-tile__label">Feature requests</p>
    <p class="analysis-stat-tile__value"><%= loop_record.insight&.feature_requests&.size || 0 %></p>
  </div>
  <div class="analysis-stat-tile">
    <p class="analysis-stat-tile__label">Overall sentiment</p>
    <p class="analysis-stat-tile__value">
      <%= sentiment_badge(loop_record.insight&.overall_sentiment) || content_tag(:span, "—", class: "text-muted fs-6") %>
    </p>
  </div>
</div>
```

**Note:** this drops the `<dl>`/`<dt>`/`<dd>` semantic list entirely — each stat is now its own card, so a definition list no longer fits the markup shape. `mb-4` moves from the removed `<dl>` onto the new wrapper so vertical spacing in `show.html.erb` is unchanged.

- [ ] **Step 2: Replace the SCSS rules for the old `<dl>` styling**

In `app/assets/stylesheets/pages/_analysis.scss`, replace lines 62-80 (the `.analysis-stat-row`, `.analysis-stat-row dt`, `.analysis-stat-row dd` blocks) with:

```scss
.analysis-stat-tiles {
  display: flex;
  flex-wrap: wrap;
  gap: $space-4;
}

.analysis-stat-tile {
  background: var(--color-surface);
  border: 1px solid var(--color-border-subtle);
  border-radius: $radius-lg;
  box-shadow: $shadow-card;
  flex: 1 1 10rem;
  padding: $space-4 $space-5;
}

.analysis-stat-tile__label {
  color: var(--color-text-muted);
  font-size: $font-size-sm;
  margin-bottom: $space-1;
  text-transform: uppercase;
}

.analysis-stat-tile__value {
  color: var(--color-text-strong);
  font-size: $font-size-2xl;
  font-weight: 700;
  margin-bottom: 0;
}
```

- [ ] **Step 3: Confirm no other view references the removed classes**

Run: `grep -rn "analysis-stat-row" app/`
Expected: no output (only `show.html.erb`'s render call for the partial remains, which doesn't reference the class name directly).

- [ ] **Step 4: Visual check**

Run: `bin/dev` (in a separate terminal/background), then open `/analyze` in a browser, click into "Per-loop overview" for a loop that has feedback.
Expected: 4 separate rounded, shadowed cards in a row (wrapping on narrow widths), matching `.analysis-card`'s visual weight but smaller. The sentiment tile shows the existing pill badge, not a plain number.

- [ ] **Step 5: Rubocop check**

Run: `bin/rubocop app/views/analyze/_stat_row.html.erb`
Expected: no offenses (rubocop doesn't lint `.erb`/`.scss` content itself, but confirms the command runs clean against the repo's config — if this specific file isn't covered by rubocop's globs, `bin/rubocop` with no args also works and should show no *new* offenses vs. before this change).

- [ ] **Step 6: Commit**

```bash
git add app/views/analyze/_stat_row.html.erb app/assets/stylesheets/pages/_analysis.scss
git commit -m "$(cat <<'EOF'
Restyle Analyze stat row as individual floating cards

Matches the rounded/shadowed look the chart card already got in
29eb48e — was still a plain dt/dd list with no card treatment.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Filter selects — pill-shaped, filled, borderless controls

**Files:**
- Modify: `app/assets/stylesheets/pages/_analysis.scss` (add new `.analysis-select` rule after the tiles added in Task 1)
- Modify: `app/views/analyze/show.html.erb` (add `analysis-select` class to every `form-select`, the custom-range date `input`s, and the "Apply" button, on both tabs)

**Interfaces:**
- Consumes: nothing new — same `form-select`/`form-control`/`btn` elements and `data-range-filter-target`/`data-action` attributes already in `show.html.erb`, untouched.
- Produces: new CSS class `.analysis-select` (and `.analysis-select-btn` for the Apply button) — no other file depends on these yet.

- [ ] **Step 1: Add the pill-select SCSS rule**

Append to `app/assets/stylesheets/pages/_analysis.scss` (after the `.analysis-stat-tile__value` rule added in Task 1):

```scss
.analysis-select {
  background-color: var(--color-surface-subtle);
  border: none;
  border-radius: $radius-pill;
}

.analysis-select-btn {
  border-radius: $radius-pill;
}
```

- [ ] **Step 2: Apply `analysis-select` to every `<select>` and custom-range `<input type="date">` in `show.html.erb`**

There are 8 such elements across the two tabs. For each, add `analysis-select` alongside the existing Bootstrap class. Example for the "All loops" date-range select (`show.html.erb:38`):

```erb
<select name="range" id="all-loops-range-select" class="form-select analysis-select" data-range-filter-target="select" data-action="change->range-filter#toggle">
```

Apply the same `analysis-select` addition (append to the existing `class="..."` attribute, no other changes) to:
- `all-loops-from-date` input (`show.html.erb:49`) — `class="form-control analysis-select"`
- `all-loops-to-date` input (`show.html.erb:53`) — `class="form-control analysis-select"`
- `status-filter-select` (`show.html.erb:74`) — `class="form-select analysis-select"`
- `sort-select` (`show.html.erb:84`) — `class="form-select analysis-select"`
- the per-loop picker `<select>` inside `.analysis-loop-select` (`show.html.erb:133`) — `class="form-select analysis-select"`
- `data-view-select` (`show.html.erb:154`) — `class="form-select analysis-select"`
- `chart-type-select` (`show.html.erb:163`) — `class="form-select analysis-select"`
- `range-select` (`show.html.erb:171`) — `class="form-select analysis-select"`
- `from-date` input (`show.html.erb:182`) — `class="form-control analysis-select"`
- `to-date` input (`show.html.erb:186`) — `class="form-control analysis-select"`

- [ ] **Step 3: Apply `analysis-select-btn` to both "Apply" buttons**

Both custom-range "Apply" buttons (`show.html.erb:56` and `show.html.erb:189`) change from:

```erb
<button type="submit" class="btn btn-outline-primary">Apply</button>
```

to:

```erb
<button type="submit" class="btn btn-outline-primary analysis-select-btn">Apply</button>
```

- [ ] **Step 4: Visual check**

With `bin/dev` still running, reload `/analyze`, check both tabs:
- All loops tab: Date range select, both custom-range date inputs, Apply button, Status select, Sort select
- Per-loop tab: per-loop picker select, Data/Chart type/Date range selects, custom-range date inputs, Apply button

Expected: every one of these is now a filled, fully-rounded pill with no visible border, and the native select caret still renders (Bootstrap's `form-select` background-image arrow isn't removed by this change — only `border`/`border-radius`/`background-color` are overridden).

- [ ] **Step 5: Confirm `range_filter_controller.js` still works**

In the browser, on the per-loop tab: change "Date range" to "Custom range" — the From/To date fields and Apply button should appear (this is `data-range-filter-target="customField"` visibility toggling, driven by the Stimulus controller, not by any class added in this task). Change it back to e.g. "Last 7 days" — the custom fields should hide and the page should reload with the new range.
Expected: toggle and submit behavior unchanged from before this task.

- [ ] **Step 6: Rubocop check**

Run: `bin/rubocop`
Expected: no new offenses introduced by this change (pre-existing offenses in `app/controllers/analyze_controller.rb` are known and out of scope, per `CLAUDE.md`).

- [ ] **Step 7: Commit**

```bash
git add app/assets/stylesheets/pages/_analysis.scss app/views/analyze/show.html.erb
git commit -m "$(cat <<'EOF'
Restyle Analyze filter selects as filled rounded pills

Matches the rounded/shadowed card look already applied elsewhere on
the page — selects were still square Bootstrap defaults.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```
