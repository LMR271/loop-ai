# Analyse Tab Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Analyse tab a coherent, restrained visual system (shared card style, ElevenLabs-style underlined tabs, a live stat row, first-time-friendly copy with scoped empty states) and replace its scattered zero-feedback placeholders with one unified empty state.

**Architecture:** View/CSS-only change. No controller, model, helper-logic, or LLM-pipeline changes. `app/assets/stylesheets/pages/_analysis.scss` gains a small set of shared classes (`.analysis-card`, `.analysis-card--tall`, `.analysis-tabs`, `.analysis-section-empty`) that existing and new partials adopt; two new partials (`_stat_row`, `_section_empty`, `_empty_loop`) get added under `app/views/analyse/`.

**Tech Stack:** Rails 8.1 views (ERB), Bootstrap 5.3 utilities, existing SCSS design tokens (`_design_tokens.scss`), Minitest `ActionDispatch::IntegrationTest` + `assert_select`/`css_select`.

## Global Constraints

- No new colors: every visual change uses existing `--color-*` custom properties from `_design_tokens.scss`. Color stays reserved for `sentiment_badge` output and the existing theme/request chip tints.
- No changes to controller logic, chart data queries, `AnalyseHelper#sentiment_badge`'s value mapping, or the LLM pipeline (`LlmClient`, `FeedbackAnalyzer`, `LoopAnalyzer`).
- Not a fix for the separately reported webhook/analysis latency issue — that is explicitly out of scope for this plan.
- Reuse the existing `.loops-empty-state` / `.loops-empty-state__icon` pattern (already defined in `app/assets/stylesheets/pages/_loops.scss`, already used in `app/views/loops/index.html.erb`) for the full-tab empty state — do not invent a new empty-state visual pattern.
- No new icon library — Font Awesome classes only (`fa-solid fa-*`), same as the rest of the app.
- `bin/ci` is pre-existing-red on `master` due to a stale `PagesControllerTest` unrelated to this work — not ours to fix; confirm any red is that one before treating a run as failing.
- Design spec: `docs/superpowers/specs/2026-07-21-analyse-visual-redesign-design.md`.

---

## Task 1: Shared card + tab CSS foundation, applied to existing cards and tabs

**Files:**
- Modify: `app/assets/stylesheets/pages/_analysis.scss`
- Modify: `app/views/analyse/show.html.erb:20,59,96-121,187`
- Modify: `app/views/analyse/_insight_panel.html.erb:1`
- Modify: `app/views/analyse/_theme.html.erb:1`
- Modify: `app/views/analyse/_feature_request.html.erb:1`
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Produces: CSS classes `.analysis-card` (base card look: surface background, hairline border, `$radius-card`, `$space-6` padding) and `.analysis-card--tall` (adds `min-height: 13.75rem`, for the chart/summary pair) and `.analysis-tabs` (underlined-tab modifier on a Bootstrap `nav-tabs` list). Later tasks apply `.analysis-card` to new elements (response cards, stat row sits alongside it, section-empty states).

- [ ] **Step 1: Update the existing test's selectors and add a feedback record**

`test/controllers/analyse_controller_test.rb` currently has:

```ruby
  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive",
                                          analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-summary-card", text: /Going well/
    assert_select ".theme-card", text: /Onboarding overwhelming/
  end
```

Replace it with (renamed CSS hooks; `feedbacks.create!` added now so this test still exercises the non-empty layout once Task 6 gates the whole tab body on `@loop.feedbacks.empty?`):

```ruby
  test "shows the insight panel and themes when an analysis exists" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive",
                                          analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-card", text: /Going well/
    assert_select ".analysis-card", text: /Onboarding overwhelming/
  end
```

- [ ] **Step 2: Run the test to see it fail against the current markup**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/shows the insight panel and themes/"`
Expected: FAIL — `.analysis-card` matches nothing yet (current markup still uses `.analysis-summary-card`/`.theme-card`).

- [ ] **Step 3: Rewrite the CSS foundation**

Replace the full contents of `app/assets/stylesheets/pages/_analysis.scss` with:

```scss
// Analysis-specific layout helpers replace former inline presentation rules.
.page-content--standard {
  max-width: 47.5rem;
}

.page-content--compact {
  max-width: 30rem;
}

.respondent-logo {
  max-height: 5rem;
}

.analysis-chart-empty {
  min-height: 10rem;
}

.analysis-loop-select {
  min-width: 16.25rem;
}

.analysis-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: $radius-card;
  padding: $space-6;
}

.analysis-card--tall {
  min-height: 13.75rem;
}

.analysis-transcript {
  white-space: pre-wrap;
}

.analysis-tabs {
  border-bottom: 1px solid var(--color-border);
}

.analysis-tabs .nav-link {
  background: none;
  border: none;
  border-bottom: 2px solid transparent;
  border-radius: 0;
  color: var(--color-text-muted);
  margin-right: $space-5;
  padding: $space-3 $space-1;
}

.analysis-tabs .nav-link.active {
  border-bottom-color: var(--color-text);
  color: var(--color-text);
  font-weight: 600;
}
```

- [ ] **Step 4: Apply the new classes across the existing markup**

In `app/views/analyse/show.html.erb`:

Line 20, tab nav — change:
```erb
    <ul class="nav nav-tabs mb-4" role="tablist">
```
to:
```erb
    <ul class="nav nav-tabs analysis-tabs mb-4" role="tablist">
```

Line 59, all-loops chart card — change:
```erb
          <div class="border rounded p-4 mb-4">
```
to:
```erb
          <div class="analysis-card mb-4">
```

Lines 96-121, all-loops table — change:
```erb
        <% if @loops_table.empty? %>
          <div class="alert alert-light border text-center py-4">
            No loops match this filter
          </div>
        <% else %>
          <div class="table-responsive">
            <table class="table align-middle">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Feedback</th>
                  <th>Description</th>
                </tr>
              </thead>
              <tbody>
                <% @loops_table.each do |loop_record| %>
                  <tr>
                    <td><%= link_to loop_record.name, analyse_path(loop_record.slug, tab: "per_loop") %></td>
                    <td><span class="badge text-bg-light"><%= loop_record.status %></span></td>
                    <td><%= loop_record.created_at.strftime("%b %d, %Y") %></td>
                    <td><%= loop_record.feedbacks.size %></td>
                    <td class="text-muted small"><%= truncate(loop_record.description, length: 80) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        <% end %>
```
to:
```erb
        <% if @loops_table.empty? %>
          <div class="alert alert-light border text-center py-4">
            No loops match this filter
          </div>
        <% else %>
          <div class="analysis-card p-0">
            <div class="table-responsive">
              <table class="table align-middle mb-0">
                <thead>
                  <tr>
                    <th>Name</th>
                    <th>Status</th>
                    <th>Created</th>
                    <th>Feedback</th>
                    <th>Description</th>
                  </tr>
                </thead>
                <tbody>
                  <% @loops_table.each do |loop_record| %>
                    <tr>
                      <td><%= link_to loop_record.name, analyse_path(loop_record.slug, tab: "per_loop") %></td>
                      <td><span class="badge text-bg-light"><%= loop_record.status %></span></td>
                      <td><%= loop_record.created_at.strftime("%b %d, %Y") %></td>
                      <td><%= loop_record.feedbacks.size %></td>
                      <td class="text-muted small"><%= truncate(loop_record.description, length: 80) %></td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>
        <% end %>
```

Line 187, per-loop chart card — change:
```erb
            <div class="analysis-chart-card h-100">
```
to:
```erb
            <div class="analysis-card analysis-card--tall h-100">
```

In `app/views/analyse/_insight_panel.html.erb`, line 1 — change:
```erb
<div class="analysis-summary-card h-100 p-4">
```
to:
```erb
<div class="analysis-card analysis-card--tall h-100">
```

In `app/views/analyse/_theme.html.erb`, line 1 — change:
```erb
<div class="theme-card border rounded p-3">
```
to:
```erb
<div class="analysis-card">
```

In `app/views/analyse/_feature_request.html.erb`, line 1 — change:
```erb
<div class="feature-request-card border rounded p-3">
```
to:
```erb
<div class="analysis-card">
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/shows the insight panel and themes/"`
Expected: PASS

- [ ] **Step 6: Run the full Analyse test suite to check for regressions**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add app/assets/stylesheets/pages/_analysis.scss app/views/analyse/show.html.erb app/views/analyse/_insight_panel.html.erb app/views/analyse/_theme.html.erb app/views/analyse/_feature_request.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: shared .analysis-card style + underlined tabs"
```

---

## Task 2: Live stat row on the Overview tab

**Files:**
- Create: `app/views/analyse/_stat_row.html.erb`
- Modify: `app/views/analyse/show.html.erb:185` (insert render call before the chart/insight row)
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `loop_record` (a `Loop`) — reads `loop_record.feedbacks.size`, `loop_record.insight&.themes&.size`, `loop_record.insight&.feature_requests&.size`, `loop_record.insight&.overall_sentiment`, and the existing `AnalyseHelper#sentiment_badge(sentiment)`.
- Produces: partial `analyse/_stat_row` rendered with `render "stat_row", loop_record: @loop`; CSS class `.analysis-stat-row` for later reference (hidden by Task 6's empty-state conditional).

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "overview shows a live stat row with response, theme, and feature request counts" do
    loop_record = @user.loops.create!(name: "L")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "T1", mention_count: 1, sentiment: "positive")
    loop_record.feedbacks.create!(transcript: "hi one")
    loop_record.feedbacks.create!(transcript: "hi two")

    get analyse_path(loop_record.slug)

    values = css_select(".analysis-stat-row dd").map(&:text)
    assert_equal ["2", "1", "0"], values[0..2]
    assert_match(/Positive/, values[3])
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/live stat row/"`
Expected: FAIL — no `.analysis-stat-row` element exists yet.

- [ ] **Step 3: Add stat-row CSS**

Append to `app/assets/stylesheets/pages/_analysis.scss`:

```scss
.analysis-stat-row {
  display: flex;
  flex-wrap: wrap;
  gap: $space-8;
}

.analysis-stat-row dt {
  color: var(--color-text-muted);
  font-size: $font-size-sm;
  margin-bottom: $space-1;
  text-transform: uppercase;
}

.analysis-stat-row dd {
  color: var(--color-text-strong);
  font-size: $font-size-2xl;
  font-weight: 700;
  margin-bottom: 0;
}
```

- [ ] **Step 4: Create the partial**

Create `app/views/analyse/_stat_row.html.erb`:

```erb
<dl class="analysis-stat-row mb-4">
  <div>
    <dt>Responses</dt>
    <dd><%= loop_record.feedbacks.size %></dd>
  </div>
  <div>
    <dt>Themes found</dt>
    <dd><%= loop_record.insight&.themes&.size || 0 %></dd>
  </div>
  <div>
    <dt>Feature requests</dt>
    <dd><%= loop_record.insight&.feature_requests&.size || 0 %></dd>
  </div>
  <div>
    <dt>Overall sentiment</dt>
    <dd><%= sentiment_badge(loop_record.insight&.overall_sentiment) || content_tag(:span, "—", class: "text-muted fs-6") %></dd>
  </div>
</dl>
```

- [ ] **Step 5: Render it in show.html.erb**

In `app/views/analyse/show.html.erb`, immediately before the `<div class="row g-4 mb-4">` that wraps the chart + insight panel (the row inserted right after the filter form's `<% end %>`), add:

```erb
        <%= render "stat_row", loop_record: @loop %>

        <div class="row g-4 mb-4">
```

(This replaces the bare `<div class="row g-4 mb-4">` line with the two lines above it.)

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/live stat row/"`
Expected: PASS

- [ ] **Step 7: Run the full Analyse test suite**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 8: Commit**

```bash
git add app/assets/stylesheets/pages/_analysis.scss app/views/analyse/_stat_row.html.erb app/views/analyse/show.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: add live stat row to the Overview tab"
```

---

## Task 3: Insight card copy — make it explicit this is an AI rollup

**Files:**
- Modify: `app/views/analyse/_insight_panel.html.erb:4-5`
- Test: `test/controllers/analyse_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "insight card explains that the summary is AI-generated from every transcript" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-card", text: /Summary of all feedback/
    assert_select ".analysis-card", text: /AI-generated from every interview transcript/
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/AI-generated from every transcript/"`
Expected: FAIL — current heading is "What people are telling you".

- [ ] **Step 3: Update the copy**

In `app/views/analyse/_insight_panel.html.erb`, change:
```erb
      <h2 class="h5 mb-1">What people are telling you</h2>
      <p class="text-muted small mb-0">The headline across every interview in this loop. Press Refresh after new responses come in.</p>
```
to:
```erb
      <h2 class="h5 mb-1">Summary of all feedback</h2>
      <p class="text-muted small mb-0">AI-generated from every interview transcript in this loop. Press Refresh after new responses come in.</p>
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/AI-generated from every transcript/"`
Expected: PASS

- [ ] **Step 5: Run the full Analyse test suite**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/analyse/_insight_panel.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: clarify the insight card is an AI summary of all feedback"
```

---

## Task 4: Scoped empty states for Themes and Feature requests

**Files:**
- Create: `app/views/analyse/_section_empty.html.erb`
- Modify: `app/assets/stylesheets/pages/_analysis.scss`
- Modify: `app/views/analyse/show.html.erb:207-231`
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: locals `icon` (a Font Awesome class suffix string, e.g. `"fa-tag"`) and `message` (a string).
- Produces: partial `analyse/_section_empty`, rendered as `render "section_empty", icon: "fa-tag", message: "..."`.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "themes and feature requests sections show a scoped empty state when the insight has neither" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    loop_record.create_insight!(summary: "S", overall_sentiment: "neutral", analyzed_feedback_count: 1)

    get analyse_path(loop_record.slug)

    assert_select ".analysis-section-empty", text: /No themes yet/
    assert_select ".analysis-section-empty", text: /No feature requests surfaced yet/
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/scoped empty state when the insight has neither/"`
Expected: FAIL — no `.analysis-section-empty` element exists yet.

- [ ] **Step 3: Add section-empty CSS**

Append to `app/assets/stylesheets/pages/_analysis.scss`:

```scss
.analysis-section-empty {
  align-items: center;
  color: var(--color-text-muted);
  display: flex;
  flex-direction: column;
  gap: $space-2;
  padding: $space-8 $space-4;
  text-align: center;
}

.analysis-section-empty i {
  font-size: $font-size-xl;
}
```

- [ ] **Step 4: Create the partial**

Create `app/views/analyse/_section_empty.html.erb`:

```erb
<div class="analysis-section-empty">
  <i class="fa-solid <%= icon %>" aria-hidden="true"></i>
  <p class="mb-0 small"><%= message %></p>
</div>
```

- [ ] **Step 5: Use it in show.html.erb**

In `app/views/analyse/show.html.erb`, change:
```erb
        <% if @loop.insight.present? %>
          <section class="mb-4">
            <h3 class="mb-1">Themes</h3>
            <p class="text-muted small mb-3">Patterns that came up across multiple interviews — where to focus.</p>
            <% if @loop.insight.themes.any? %>
              <div class="d-flex flex-column gap-2">
                <%= render partial: "theme", collection: @loop.insight.themes, as: :theme %>
              </div>
            <% else %>
              <div class="alert alert-light border small mb-0">No themes yet — collect a few interviews, then Refresh.</div>
            <% end %>
          </section>

          <section class="mb-4">
            <h3 class="mb-1">Feature requests</h3>
            <p class="text-muted small mb-3">Specific things respondents asked you to build.</p>
            <% if @loop.insight.feature_requests.any? %>
              <div class="d-flex flex-column gap-2">
                <%= render partial: "feature_request", collection: @loop.insight.feature_requests, as: :feature_request %>
              </div>
            <% else %>
              <div class="alert alert-light border small mb-0">No feature requests surfaced yet.</div>
            <% end %>
          </section>
        <% end %>
```
to:
```erb
        <% if @loop.insight.present? %>
          <section class="mb-4">
            <h3 class="mb-1">Themes</h3>
            <p class="text-muted small mb-3">Patterns that came up across multiple interviews — where to focus.</p>
            <% if @loop.insight.themes.any? %>
              <div class="d-flex flex-column gap-2">
                <%= render partial: "theme", collection: @loop.insight.themes, as: :theme %>
              </div>
            <% else %>
              <%= render "section_empty", icon: "fa-tag", message: "No themes yet — collect a few interviews, then Refresh." %>
            <% end %>
          </section>

          <section class="mb-4">
            <h3 class="mb-1">Feature requests</h3>
            <p class="text-muted small mb-3">Specific things respondents asked you to build.</p>
            <% if @loop.insight.feature_requests.any? %>
              <div class="d-flex flex-column gap-2">
                <%= render partial: "feature_request", collection: @loop.insight.feature_requests, as: :feature_request %>
              </div>
            <% else %>
              <%= render "section_empty", icon: "fa-lightbulb", message: "No feature requests surfaced yet." %>
            <% end %>
          </section>
        <% end %>
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/scoped empty state when the insight has neither/"`
Expected: PASS

- [ ] **Step 7: Run the full Analyse test suite**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 8: Commit**

```bash
git add app/assets/stylesheets/pages/_analysis.scss app/views/analyse/_section_empty.html.erb app/views/analyse/show.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: scoped icon empty states for Themes and Feature requests"
```

---

## Task 5: Response cards — label the AI summary, adopt the shared card style

**Files:**
- Modify: `app/views/analyse/show.html.erb:233-267`
- Test: `test/controllers/analyse_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "response cards label the AI-generated summary and use the shared card style" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "raw words", title: "Title", summary: "Generated summary")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-response-card", text: /AI summary/
    assert_select ".analysis-response-card", text: /Generated summary/
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/label the AI-generated summary/"`
Expected: FAIL — no `.analysis-response-card` element and no "AI summary" label exist yet.

- [ ] **Step 3: Update the response card markup**

In `app/views/analyse/show.html.erb`, change:
```erb
        <h3 class="mb-1">Every response</h3>
        <p class="text-muted small mb-3">Each interview in full. Chips show the themes and requests we pulled from that one conversation.</p>

        <% if @feedbacks.empty? %>
          <div class="alert alert-light border text-center py-5">
            <%= @loop.feedbacks.any? ? "No feedback in this range" : "No feedback yet" %>
          </div>
        <% else %>
          <div class="d-flex flex-column gap-3">
            <% @feedbacks.each do |feedback| %>
              <div class="border rounded p-3">
                <div class="d-flex justify-content-between align-items-start mb-2 gap-2">
                  <span class="fw-semibold"><%= feedback.respondent_email.presence || "Anonymous respondent" %></span>
                  <div class="d-flex align-items-center gap-2">
                    <%= sentiment_badge(feedback.sentiment) %>
                    <span class="text-muted small text-nowrap"><%= feedback.created_at.strftime("%b %d, %Y at %I:%M %p") %></span>
                  </div>
                </div>
                <% if feedback.summary.present? %>
                  <p class="fw-semibold mb-1"><%= feedback.title %></p>
                  <p class="mb-2"><%= feedback.summary %></p>
                  <details class="mb-0">
                    <summary class="small text-muted">View full transcript</summary>
                    <p class="analysis-transcript mb-0 mt-2"><%= feedback.transcript %></p>
                  </details>
                <% else %>
                  <p class="analysis-transcript mb-0"><%= feedback.transcript %></p>
                <% end %>
                <%= render "extracted_points", feedback: feedback %>
                <% if feedback.sentiment_rationale.present? %>
                  <p class="text-muted small fst-italic mb-0 mt-2 pt-2 border-top">
                    <i class="fa-solid fa-wand-magic-sparkles me-1"></i><%= feedback.sentiment_rationale %>
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
```
to:
```erb
        <h3 class="mb-1">Every response</h3>
        <p class="text-muted small mb-3">Each interview in full. The summary above the transcript is AI-generated — the transcript itself is the respondent's own words.</p>

        <% if @feedbacks.empty? %>
          <div class="alert alert-light border text-center py-5">
            <%= @loop.feedbacks.any? ? "No feedback in this range" : "No feedback yet" %>
          </div>
        <% else %>
          <div class="d-flex flex-column gap-3">
            <% @feedbacks.each do |feedback| %>
              <div class="analysis-card analysis-response-card">
                <div class="d-flex justify-content-between align-items-start mb-2 gap-2">
                  <span class="fw-semibold"><%= feedback.respondent_email.presence || "Anonymous respondent" %></span>
                  <div class="d-flex align-items-center gap-2">
                    <%= sentiment_badge(feedback.sentiment) %>
                    <span class="text-muted small text-nowrap"><%= feedback.created_at.strftime("%b %d, %Y at %I:%M %p") %></span>
                  </div>
                </div>
                <% if feedback.summary.present? %>
                  <p class="text-uppercase text-muted small fw-semibold mb-1">AI summary</p>
                  <p class="fw-semibold mb-1"><%= feedback.title %></p>
                  <p class="mb-2"><%= feedback.summary %></p>
                  <details class="mb-0">
                    <summary class="small text-muted">View full transcript</summary>
                    <p class="analysis-transcript mb-0 mt-2"><%= feedback.transcript %></p>
                  </details>
                <% else %>
                  <p class="analysis-transcript mb-0"><%= feedback.transcript %></p>
                <% end %>
                <%= render "extracted_points", feedback: feedback %>
                <% if feedback.sentiment_rationale.present? %>
                  <p class="text-muted small fst-italic mb-0 mt-2 pt-2 border-top">
                    <i class="fa-solid fa-wand-magic-sparkles me-1"></i><%= feedback.sentiment_rationale %>
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/label the AI-generated summary/"`
Expected: PASS

- [ ] **Step 5: Run the full Analyse test suite**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/analyse/show.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: label response summaries as AI-generated, adopt shared card style"
```

---

## Task 6: One unified empty state for a loop with zero feedback ever

**Files:**
- Create: `app/views/analyse/_empty_loop.html.erb`
- Modify: `app/views/analyse/show.html.erb:124-271` (wrap the per-loop tab-pane body)
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Produces: partial `analyse/_empty_loop`, rendered as `render "empty_loop"` (no locals — uses `deploy_path`, a route helper with no required params).

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "a loop with no feedback ever shows one unified empty state instead of scattered empty boxes" do
    loop_record = @user.loops.create!(name: "L")

    get analyse_path(loop_record.slug)

    assert_select "#per-loop-pane" do
      assert_select ".loops-empty-state", text: /No feedback yet/
      assert_select ".analysis-stat-row", count: 0
      assert_select ".analysis-card", count: 0
    end
  end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/unified empty state instead of scattered/"`
Expected: FAIL — no `.loops-empty-state` renders in `#per-loop-pane` yet; the chart card (`.analysis-card`) still renders.

- [ ] **Step 3: Create the empty-state partial**

Create `app/views/analyse/_empty_loop.html.erb`:

```erb
<section class="loops-empty-state text-center" aria-labelledby="empty-analyse-heading">
  <div class="loops-empty-state__icon" aria-hidden="true"><i class="fa-solid fa-comment-dots"></i></div>
  <h2 id="empty-analyse-heading">No feedback yet</h2>
  <p class="text-muted mb-4">Share your loop's link to start collecting responses.</p>
  <%= link_to "Go to Deploy", deploy_path, class: "btn btn-primary" %>
</section>
```

- [ ] **Step 4: Wrap the per-loop tab-pane body**

In `app/views/analyse/show.html.erb`, the `#per-loop-pane` div (after Tasks 1–5) currently runs from its opening tag through the "Every response" section. Replace the entire `<div class="tab-pane fade ..." id="per-loop-pane" ...> ... </div>` block with:

```erb
      <div class="tab-pane fade <%= "show active" if @active_tab == "per_loop" %>" id="per-loop-pane" role="tabpanel">
        <div class="d-flex justify-content-between align-items-center mb-4">
          <h2 class="mb-0">Overview of #<%= @loop.name %></h2>

          <% if @loops.any? %>
            <div class="analysis-loop-select">
              <select class="form-select" onchange="if (this.value) { window.location.href = this.value }">
                <% @loops.each do |loop_record| %>
                  <option value="<%= analyse_path(loop_record.slug, tab: @active_tab, range: @range, from: params[:from], to: params[:to], chart_type: @chart_type, data_view: @data_view) %>" <%= "selected" if @loop && loop_record.id == @loop.id %>>
                    <%= loop_record.name %>
                  </option>
                <% end %>
              </select>
            </div>
          <% end %>
        </div>

        <% if @loop.feedbacks.empty? %>
          <%= render "empty_loop" %>
        <% else %>
          <%= render "stat_row", loop_record: @loop %>

          <%= form_with url: analyse_path(@loop.slug), method: :get, data: { controller: "range-filter" }, class: "d-flex flex-wrap align-items-end gap-3 mb-4" do %>
            <%= hidden_field_tag :tab, "per_loop" %>

            <div>
              <label class="form-label small text-muted mb-1" for="data-view-select">Data</label>
              <select name="data_view" id="data-view-select" class="form-select" data-action="change->range-filter#submit">
                <option value="volume" <%= "selected" if @data_view == "volume" %>>Feedback volume</option>
                <option value="day_of_week" <%= "selected" if @data_view == "day_of_week" %>>Responses by day of week</option>
                <option value="cumulative" <%= "selected" if @data_view == "cumulative" %>>Cumulative feedback</option>
              </select>
            </div>

            <div>
              <label class="form-label small text-muted mb-1" for="chart-type-select">Chart type</label>
              <select name="chart_type" id="chart-type-select" class="form-select" data-action="change->range-filter#submit">
                <option value="bar" <%= "selected" if @chart_type == "bar" %>>Bar</option>
                <option value="line" <%= "selected" if @chart_type == "line" %>>Line</option>
              </select>
            </div>

            <div>
              <label class="form-label small text-muted mb-1" for="range-select">Date range</label>
              <select name="range" id="range-select" class="form-select" data-range-filter-target="select" data-action="change->range-filter#toggle">
                <option value="24h" <%= "selected" if @range == "24h" %>>Last 24 hours</option>
                <option value="7d" <%= "selected" if @range == "7d" %>>Last 7 days</option>
                <option value="14d" <%= "selected" if @range == "14d" %>>Last 14 days</option>
                <option value="30d" <%= "selected" if @range == "30d" %>>Last 30 days</option>
                <option value="custom" <%= "selected" if @range == "custom" %>>Custom range</option>
              </select>
            </div>

            <div class="<%= "d-none" unless @range == "custom" %>" data-range-filter-target="customField">
              <label class="form-label small text-muted mb-1" for="from-date">From</label>
              <input type="date" name="from" id="from-date" class="form-control" value="<%= params[:from] %>">
            </div>
            <div class="<%= "d-none" unless @range == "custom" %>" data-range-filter-target="customField">
              <label class="form-label small text-muted mb-1" for="to-date">To</label>
              <input type="date" name="to" id="to-date" class="form-control" value="<%= params[:to] %>">
            </div>
            <div class="<%= "d-none" unless @range == "custom" %>" data-range-filter-target="customField">
              <button type="submit" class="btn btn-outline-primary">Apply</button>
            </div>
          <% end %>

          <div class="row g-4 mb-4">
            <div class="col-md-8">
              <div class="analysis-card analysis-card--tall h-100">
                <h3 class="h6 text-uppercase text-muted mb-3">
                  <%= chart_title(@data_view) %> (<%= range_label(@range, @from, @to) %>)
                </h3>
                <% if @active_chart_data.values.sum.zero? %>
                  <div class="analysis-chart-empty d-flex align-items-center justify-content-center text-muted">
                    No feedback to chart in this range
                  </div>
                <% elsif @chart_type == "line" %>
                  <%= line_chart @active_chart_data, **chart_options %>
                <% else %>
                  <%= column_chart @active_chart_data, **chart_options %>
                <% end %>
              </div>
            </div>
            <div class="col-md-4">
              <%= render "insight_panel", loop_record: @loop %>
            </div>
          </div>

          <% if @loop.insight.present? %>
            <section class="mb-4">
              <h3 class="mb-1">Themes</h3>
              <p class="text-muted small mb-3">Patterns that came up across multiple interviews — where to focus.</p>
              <% if @loop.insight.themes.any? %>
                <div class="d-flex flex-column gap-2">
                  <%= render partial: "theme", collection: @loop.insight.themes, as: :theme %>
                </div>
              <% else %>
                <%= render "section_empty", icon: "fa-tag", message: "No themes yet — collect a few interviews, then Refresh." %>
              <% end %>
            </section>

            <section class="mb-4">
              <h3 class="mb-1">Feature requests</h3>
              <p class="text-muted small mb-3">Specific things respondents asked you to build.</p>
              <% if @loop.insight.feature_requests.any? %>
                <div class="d-flex flex-column gap-2">
                  <%= render partial: "feature_request", collection: @loop.insight.feature_requests, as: :feature_request %>
                </div>
              <% else %>
                <%= render "section_empty", icon: "fa-lightbulb", message: "No feature requests surfaced yet." %>
              <% end %>
            </section>
          <% end %>

          <h3 class="mb-1">Every response</h3>
          <p class="text-muted small mb-3">Each interview in full. The summary above the transcript is AI-generated — the transcript itself is the respondent's own words.</p>

          <% if @feedbacks.empty? %>
            <div class="alert alert-light border text-center py-5">
              No feedback in this range
            </div>
          <% else %>
            <div class="d-flex flex-column gap-3">
              <% @feedbacks.each do |feedback| %>
                <div class="analysis-card analysis-response-card">
                  <div class="d-flex justify-content-between align-items-start mb-2 gap-2">
                    <span class="fw-semibold"><%= feedback.respondent_email.presence || "Anonymous respondent" %></span>
                    <div class="d-flex align-items-center gap-2">
                      <%= sentiment_badge(feedback.sentiment) %>
                      <span class="text-muted small text-nowrap"><%= feedback.created_at.strftime("%b %d, %Y at %I:%M %p") %></span>
                    </div>
                  </div>
                  <% if feedback.summary.present? %>
                    <p class="text-uppercase text-muted small fw-semibold mb-1">AI summary</p>
                    <p class="fw-semibold mb-1"><%= feedback.title %></p>
                    <p class="mb-2"><%= feedback.summary %></p>
                    <details class="mb-0">
                      <summary class="small text-muted">View full transcript</summary>
                      <p class="analysis-transcript mb-0 mt-2"><%= feedback.transcript %></p>
                    </details>
                  <% else %>
                    <p class="analysis-transcript mb-0"><%= feedback.transcript %></p>
                  <% end %>
                  <%= render "extracted_points", feedback: feedback %>
                  <% if feedback.sentiment_rationale.present? %>
                    <p class="text-muted small fst-italic mb-0 mt-2 pt-2 border-top">
                      <i class="fa-solid fa-wand-magic-sparkles me-1"></i><%= feedback.sentiment_rationale %>
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
```

Note the inner "Every response" empty message is simplified to a flat `"No feedback in this range"` — the outer `@loop.feedbacks.empty?` branch above already guarantees the loop has *some* feedback whenever this branch renders, so the old `@loop.feedbacks.any? ? ... : ...` ternary is now redundant.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/unified empty state instead of scattered/"`
Expected: PASS

- [ ] **Step 6: Run the full Analyse test suite**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add app/views/analyse/_empty_loop.html.erb app/views/analyse/show.html.erb test/controllers/analyse_controller_test.rb
git commit -m "Analyse: one unified empty state for a loop with zero feedback ever"
```

---

## Task 7: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: all PASS except the pre-existing, unrelated `PagesControllerTest#test_signed-in_visitors_can_view_the_landing_page` failure (known-red on `master`, not introduced by this work).

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: no new offenses (this plan touches no `.rb` files outside the test file, whose additions are short single-assertion tests well within the existing method-length conventions).

- [ ] **Step 3: Manual check in the browser**

Start the dev server (`bin/dev`) and visit `/analyse/:slug` for:
- A loop with zero feedback ever → confirm the single unified empty state renders (icon, "No feedback yet", "Go to Deploy" button) and nothing else (no stat row, no chart, no insight card).
- A loop with feedback but no insight yet → confirm the stat row shows correct counts (themes/feature requests as 0, sentiment as "—"), and the insight card still shows its existing "no analysis yet" copy.
- A loop with an insight missing themes or feature requests → confirm the scoped icon empty state renders for just that section.
- A fully analyzed loop → confirm all sections render normally, response cards show the "AI summary" label, and color usage is limited to sentiment badges and theme/request chip tints.
- The `all_loops` tab → confirm the chart card and table use the same `.analysis-card` styling and the tabs read as underlined text, not filled pills.

- [ ] **Step 4: Commit any final fixups**

```bash
git status
```

If Step 1–3 surfaced no changes, there is nothing to commit here — this task is verification-only.
