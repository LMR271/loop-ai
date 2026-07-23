# Patterns & Feature Request Tiles Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Analyze page's Themes/Feature-requests sections into a 2-column grid of collapsible, bolder tiles, rename "Themes" to "Patterns", and tag each quote with a numbered, sentiment-badged, clickable link back to its source interview.

**Architecture:** Pure Rails view/helper/controller changes — one new controller-computed hash (`@interview_numbers`), one new view helper (`interview_tag_link`), two rewritten partials (`_theme.html.erb`, `_feature_request.html.erb`) using native `<details>`/`<summary>` for collapse (no JS), Bootstrap `row-cols` grid classes for layout, and new SCSS for the tile chrome. No model, job, or route changes.

**Tech Stack:** Rails 8.1 views/ERB, Bootstrap 5.3 utility classes, SCSS (`app/assets/stylesheets/pages/_analysis.scss`), Minitest `ActionDispatch::IntegrationTest` + `assert_select`.

## Global Constraints

- Headline "Themes" → "Patterns"; the subtitle text directly beneath it is left completely unchanged (approved, intentionally slightly redundant).
- No new JavaScript/Stimulus controller — collapse/expand must use native `<details>`/`<summary>`, matching the existing "View full transcript" pattern in `show.html.erb`.
- 2 columns on desktop, 1 column on narrow screens, for both the Patterns and Feature requests sections.
- Tiles collapsed by default; each tile toggles independently (no accordion behavior).
- Title, sentiment badge, mention-count badge (Theme only — `FeatureRequest` has no `sentiment`/`mention_count` column), and description are always visible; only the quote list is hidden until expanded.
- Every quote shows "Interview #N" (numbered by ascending `created_at` across the loop's **entire** history, not the current date-range filter) plus that specific `quote.feedback`'s own sentiment badge.
- "Interview #N" links to `analyze_path(loop.slug, range: "custom", from: <that day>, to: <that day>, anchor: "feedback-<id>")` so the target is always present in "Every response" regardless of the page's current range filter.
- New styling must reuse existing `$space-*`/`$radius-*`/`$shadow-*` tokens and `--color-*` custom properties (`app/assets/stylesheets/config/_design_tokens.scss`) — no new bespoke values, per project convention.
- Existing `.analysis-card` class must remain on the tile root element (existing tests assert `.analysis-card` text matches for themes) — the new tile class is additive, not a replacement.

---

### Task 1: Compute per-loop interview numbers and add anchor ids to response cards

**Files:**
- Modify: `app/controllers/analyze_controller.rb:49-58` (`load_per_loop_data`)
- Modify: `app/views/analyze/show.html.erb:250-251` (the `@feedbacks.each` block, response card div)
- Test: `test/controllers/analyze_controller_test.rb`

**Interfaces:**
- Produces: `@interview_numbers` — a `Hash` of `{ feedback_id (Integer) => interview_number (Integer, 1-based) }`, covering **all** of `@loop.feedbacks` ordered by `created_at` ascending (not range-filtered). Later tasks (the theme/feature_request partials) read this via `interview_numbers.fetch(quote.feedback_id)`.
- Produces: each response card in "Every response" gets `id="feedback-<%= feedback.id %>"`, the anchor target for interview links added in Task 2.

- [ ] **Step 1: Write the failing test for `@interview_numbers` ordering and the anchor id**

Add to `test/controllers/analyze_controller_test.rb` (inside the main `describe`/class body, near the other `show` tests):

```ruby
  test "response cards are anchored by feedback id so interview links can jump to them" do
    loop_record = @user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi")

    get analyze_path(loop_record.slug)

    assert_select "##{ActionView::RecordIdentifier.dom_id(feedback, :feedback)}"
  end
```

Since `dom_id(feedback, :feedback)` produces `"feedback_#{feedback.id}"` (underscore), but the spec calls for `id="feedback-<id>"` (hyphen) to match the CSS/URL convention already used elsewhere in this app (`analysis-card`, kebab-case classes), do **not** use `dom_id` in the view — write the test against the literal id instead so the test doesn't silently accept the wrong separator:

```ruby
  test "response cards are anchored by feedback id so interview links can jump to them" do
    loop_record = @user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi")

    get analyze_path(loop_record.slug)

    assert_select "#feedback-#{feedback.id}"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/response cards are anchored/"`
Expected: FAIL (no element with that id yet)

- [ ] **Step 3: Add the anchor id in the view**

In `app/views/analyze/show.html.erb`, the response card currently reads:

```erb
              <% @feedbacks.each do |feedback| %>
                <div class="analysis-card analysis-response-card">
```

Change to:

```erb
              <% @feedbacks.each do |feedback| %>
                <div class="analysis-card analysis-response-card" id="feedback-<%= feedback.id %>">
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/response cards are anchored/"`
Expected: PASS

- [ ] **Step 5: Write the failing test for `@interview_numbers` (numbered oldest-first, independent of the range filter)**

Add:

```ruby
  test "interview numbers are assigned oldest-first across the loop's full history, ignoring the range filter" do
    loop_record = @user.loops.create!(name: "L")
    older = loop_record.feedbacks.create!(transcript: "old one", created_at: 40.days.ago)
    newer = loop_record.feedbacks.create!(transcript: "new one", created_at: 1.day.ago)
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 2)
    theme = insight.themes.create!(title: "T1", mention_count: 2, sentiment: "positive")
    theme.quotes.create!(feedback: older, text: "old quote")
    theme.quotes.create!(feedback: newer, text: "new quote")

    # default range is 30 days, so `older` (40 days ago) would be excluded from "Every response"
    # if numbering were computed off the range-scoped @feedbacks instead of the full history.
    get analyze_path(loop_record.slug)

    assert_select ".analysis-quote-tag", text: /Interview #1/
    assert_select ".analysis-quote-tag", text: /Interview #2/
  end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/interview numbers are assigned/"`
Expected: FAIL (no `.analysis-quote-tag` element exists yet — that's added in Task 3, but this test also exercises `@interview_numbers`, so leave it written now and revisit after Task 3 if it still fails for the wrong reason)

- [ ] **Step 7: Compute `@interview_numbers` in the controller**

In `app/controllers/analyze_controller.rb`, `load_per_loop_data` currently reads:

```ruby
  def load_per_loop_data
    @chart_type = params[:chart_type].presence_in(CHART_TYPES) || "bar"
    @data_view = params[:data_view].presence_in(DATA_VIEWS) || "volume"

    scoped_feedbacks = @loop ? @loop.feedbacks.where(created_at: @from..@to) : Feedback.none
    @feedbacks = scoped_feedbacks.order(created_at: :desc)
    @feedback_counts_by_day = feedback_counts_by_period(scoped_feedbacks)
    @day_of_week_counts = scoped_feedbacks.group_by_day_of_week(:created_at, format: "%A").count
    @active_chart_data = active_chart_data
  end
```

Change to:

```ruby
  def load_per_loop_data
    @chart_type = params[:chart_type].presence_in(CHART_TYPES) || "bar"
    @data_view = params[:data_view].presence_in(DATA_VIEWS) || "volume"

    scoped_feedbacks = @loop ? @loop.feedbacks.where(created_at: @from..@to) : Feedback.none
    @feedbacks = scoped_feedbacks.order(created_at: :desc)
    @feedback_counts_by_day = feedback_counts_by_period(scoped_feedbacks)
    @day_of_week_counts = scoped_feedbacks.group_by_day_of_week(:created_at, format: "%A").count
    @active_chart_data = active_chart_data
    @interview_numbers = interview_numbers_for(@loop)
  end

  def interview_numbers_for(loop_record)
    return {} unless loop_record

    loop_record.feedbacks.order(:created_at).ids.each_with_index.to_h { |id, index| [id, index + 1] }
  end
```

Note: `interview_numbers_for` goes in the `private` section, right after `load_per_loop_data` (it's already inside the `private` block that starts above `load_shared_data`).

- [ ] **Step 8: Run both new tests**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/interview numbers are assigned/" -n "/response cards are anchored/"`
Expected: the anchor-id test PASSes; the interview-numbers test still FAILs (no `.analysis-quote-tag` markup exists until Task 3) — confirm the failure is specifically a missing-element assertion failure, not an error, then proceed to Task 2/3.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/analyze_controller.rb app/views/analyze/show.html.erb test/controllers/analyze_controller_test.rb
git commit -m "Add per-loop interview numbering and response-card anchors"
```

---

### Task 2: Add the `interview_tag_link` view helper

**Files:**
- Modify: `app/helpers/analyze_helper.rb`
- Test: `test/helpers/analyze_helper_test.rb`

**Interfaces:**
- Consumes: `Loop#slug`, `Feedback#id`, `Feedback#created_at`, the `analyze_path` route helper (already used throughout `app/views/analyze/show.html.erb`), `interview_numbers` (the `Hash` produced by Task 1's `@interview_numbers`).
- Produces: `interview_tag_link(loop_record, feedback, interview_numbers)` — returns a Rails `link_to` HTML-safe string reading `"Interview #N"`, linking to that feedback's anchor with a `custom` range covering its day. Task 3/4 partials call this directly.

- [ ] **Step 1: Write the failing test**

`test/helpers/analyze_helper_test.rb` already exists (per the earlier `find` — confirm its current class name/style by opening it before adding) but if it's minimal, add:

```ruby
  test "interview_tag_link labels the interview by its position and links to its anchored, range-widened URL" do
    user = User.create!(email: "founder@example.com", password: "password123")
    loop_record = user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi", created_at: Time.zone.parse("2026-07-01 10:00"))
    interview_numbers = { feedback.id => 3 }

    html = interview_tag_link(loop_record, feedback, interview_numbers)

    assert_match(/Interview #3/, html)
    assert_match("range=custom", html)
    assert_match("from=2026-07-01", html)
    assert_match("to=2026-07-01", html)
    assert_match("#feedback-#{feedback.id}", html)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/analyze_helper_test.rb -n "/interview_tag_link/"`
Expected: FAIL with `NoMethodError: undefined method 'interview_tag_link'`

- [ ] **Step 3: Implement the helper**

In `app/helpers/analyze_helper.rb`, add (near `sentiment_badge`, since both render quote/interview-adjacent UI):

```ruby
  # "Interview #N" numbering is assigned by AnalyzeController (oldest feedback = #1) across the
  # loop's whole history, not the page's current date-range filter — see interview_numbers_for.
  # The link forces a custom range covering the interview's own day so the anchor always exists
  # on the target page, regardless of what range was selected when the link was clicked.
  def interview_tag_link(loop_record, feedback, interview_numbers)
    number = interview_numbers.fetch(feedback.id)
    day = feedback.created_at.to_date

    link_to "Interview ##{number}",
            analyze_path(loop_record.slug, range: "custom", from: day, to: day, anchor: "feedback-#{feedback.id}"),
            class: "analysis-quote-tag__link"
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/helpers/analyze_helper_test.rb -n "/interview_tag_link/"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/helpers/analyze_helper.rb test/helpers/analyze_helper_test.rb
git commit -m "Add interview_tag_link helper for per-quote interview links"
```

---

### Task 3: Rewrite the Patterns (themes) section — grid, collapsible tile, quote tags

**Files:**
- Modify: `app/views/analyze/_theme.html.erb`
- Modify: `app/views/analyze/show.html.erb:216-226` (the Themes `<section>`)
- Test: `test/controllers/analyze_controller_test.rb`

**Interfaces:**
- Consumes: `interview_tag_link(loop_record, feedback, interview_numbers)` from Task 2; `@interview_numbers` from Task 1; `sentiment_badge(sentiment)` (existing, `app/helpers/analyze_helper.rb`).
- Produces: the `_theme` partial's root element is now `<div class="col">` wrapping a `<details class="analysis-card analysis-tile">` — Task 4's `_feature_request` partial follows the identical wrapper/tile structure for visual consistency.

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/analyze_controller_test.rb`:

```ruby
  test "Themes headline reads Patterns" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    loop_record.create_insight!(summary: "S", overall_sentiment: "neutral", analyzed_feedback_count: 1)

    get analyze_path(loop_record.slug)

    assert_select "h3", text: "Patterns"
    assert_select "h3", text: "Themes", count: 0
  end

  test "theme tiles render as collapsible details with a quote's interview tag and sentiment" do
    loop_record = @user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi", sentiment: "positive")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    theme = insight.themes.create!(title: "Onboarding overwhelming", mention_count: 1, sentiment: "frustrated")
    theme.quotes.create!(feedback: feedback, text: "it was a lot")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-tile", 1 do
      assert_select "summary .analysis-tile__title", text: "Onboarding overwhelming"
    end
    assert_select ".analysis-quote-tag" do
      assert_select "a", text: "Interview #1"
      assert_select ".badge", text: "Positive"
    end
  end

  test "theme tiles are laid out two per row" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "T1", mention_count: 1, sentiment: "positive")
    insight.themes.create!(title: "T2", mention_count: 1, sentiment: "positive")

    get analyze_path(loop_record.slug)

    assert_select ".row-cols-md-2 > .col", 2
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/Patterns|collapsible details|laid out two per row/"`
Expected: FAIL (headline still "Themes", no `.analysis-tile`/`.analysis-quote-tag`/`.row-cols-md-2` markup yet)

- [ ] **Step 3: Rewrite `_theme.html.erb`**

Replace the entire file with:

```erb
<div class="col">
  <details class="analysis-card analysis-tile">
    <summary class="analysis-tile__summary">
      <div class="d-flex justify-content-between align-items-start gap-2">
        <span class="analysis-tile__title"><%= theme.title %></span>
        <div class="d-flex align-items-center gap-2 flex-shrink-0">
          <%= sentiment_badge(theme.sentiment) %>
          <span class="badge text-bg-light"><%= pluralize(theme.mention_count, "interview") %></span>
          <i class="fa-solid fa-chevron-down analysis-tile__chevron" aria-hidden="true"></i>
        </div>
      </div>
      <p class="text-muted small mb-0 mt-1"><%= theme.description %></p>
    </summary>
    <div class="analysis-tile__body mt-2">
      <% theme.quotes.each do |quote| %>
        <blockquote class="border-start ps-2 mb-1 small fst-italic text-muted">
          "<%= quote.text %>"
        </blockquote>
        <div class="analysis-quote-tag mb-2">
          <%= interview_tag_link(loop_record, quote.feedback, interview_numbers) %>
          <%= sentiment_badge(quote.feedback.sentiment) %>
        </div>
      <% end %>
    </div>
  </details>
</div>
```

- [ ] **Step 4: Update the Themes section in `show.html.erb`**

Currently (`show.html.erb:216-226`):

```erb
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
```

Change to:

```erb
            <section class="mb-4">
              <h3 class="mb-1">Patterns</h3>
              <p class="text-muted small mb-3">Patterns that came up across multiple interviews — where to focus.</p>
              <% if @loop.insight.themes.any? %>
                <div class="row row-cols-1 row-cols-md-2 g-4">
                  <%= render partial: "theme", collection: @loop.insight.themes, as: :theme,
                             locals: { loop_record: @loop, interview_numbers: @interview_numbers } %>
                </div>
              <% else %>
                <%= render "section_empty", icon: "fa-tag", message: "No themes yet — collect a few interviews, then Refresh." %>
              <% end %>
            </section>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/Patterns|collapsible details|laid out two per row|interview numbers are assigned/"`
Expected: all PASS, including the Task 1 test that was left red (`interview numbers are assigned...`)

- [ ] **Step 6: Run the full existing analyze controller test file to check for regressions**

Run: `bin/rails test test/controllers/analyze_controller_test.rb`
Expected: all PASS (the pre-existing "shows the insight panel and themes" test at line 20 still passes because `.analysis-card` is still present on the tile root)

- [ ] **Step 7: Commit**

```bash
git add app/views/analyze/_theme.html.erb app/views/analyze/show.html.erb test/controllers/analyze_controller_test.rb
git commit -m "Redesign Patterns tiles: grid layout, collapsible details, quote interview tags"
```

---

### Task 4: Apply the same tile treatment to Feature requests

**Files:**
- Modify: `app/views/analyze/_feature_request.html.erb`
- Modify: `app/views/analyze/show.html.erb:228-238` (the Feature requests `<section>`)
- Test: `test/controllers/analyze_controller_test.rb`

**Interfaces:**
- Consumes: same `interview_tag_link`/`sentiment_badge`/`@interview_numbers` as Task 3. `FeatureRequest` has no `sentiment` or `mention_count` column (`app/models/feature_request.rb`), so its `<summary>` omits those two badges.

- [ ] **Step 1: Write the failing tests**

Add:

```ruby
  test "feature request tiles render as collapsible details with a quote's interview tag" do
    loop_record = @user.loops.create!(name: "L")
    feedback = loop_record.feedbacks.create!(transcript: "hi", sentiment: "neutral")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    feature_request = insight.feature_requests.create!(title: "Dark mode", description: "Users want it")
    feature_request.quotes.create!(feedback: feedback, text: "please add dark mode")

    get analyze_path(loop_record.slug)

    assert_select ".analysis-tile", 1 do
      assert_select "summary .analysis-tile__title", text: "Dark mode"
    end
    assert_select ".analysis-quote-tag a", text: "Interview #1"
  end

  test "feature request tiles are laid out two per row" do
    loop_record = @user.loops.create!(name: "L")
    loop_record.feedbacks.create!(transcript: "hi")
    insight = loop_record.create_insight!(summary: "S", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.feature_requests.create!(title: "F1", description: "d")
    insight.feature_requests.create!(title: "F2", description: "d")

    get analyze_path(loop_record.slug)

    assert_select ".row-cols-md-2 > .col", 2
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/feature request tiles/"`
Expected: FAIL (no `.analysis-tile`/grid markup on feature requests yet)

- [ ] **Step 3: Rewrite `_feature_request.html.erb`**

Replace the entire file with:

```erb
<div class="col">
  <details class="analysis-card analysis-tile">
    <summary class="analysis-tile__summary">
      <div class="d-flex justify-content-between align-items-start gap-2">
        <span class="analysis-tile__title"><%= feature_request.title %></span>
        <i class="fa-solid fa-chevron-down analysis-tile__chevron flex-shrink-0" aria-hidden="true"></i>
      </div>
      <p class="text-muted small mb-0 mt-1"><%= feature_request.description %></p>
    </summary>
    <div class="analysis-tile__body mt-2">
      <% feature_request.quotes.each do |quote| %>
        <blockquote class="border-start ps-2 mb-1 small fst-italic text-muted">"<%= quote.text %>"</blockquote>
        <div class="analysis-quote-tag mb-2">
          <%= interview_tag_link(loop_record, quote.feedback, interview_numbers) %>
          <%= sentiment_badge(quote.feedback.sentiment) %>
        </div>
      <% end %>
    </div>
  </details>
</div>
```

- [ ] **Step 4: Update the Feature requests section in `show.html.erb`**

Currently (`show.html.erb:228-238`):

```erb
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
```

Change to:

```erb
            <section class="mb-4">
              <h3 class="mb-1">Feature requests</h3>
              <p class="text-muted small mb-3">Specific things respondents asked you to build.</p>
              <% if @loop.insight.feature_requests.any? %>
                <div class="row row-cols-1 row-cols-md-2 g-4">
                  <%= render partial: "feature_request", collection: @loop.insight.feature_requests, as: :feature_request,
                             locals: { loop_record: @loop, interview_numbers: @interview_numbers } %>
                </div>
              <% else %>
                <%= render "section_empty", icon: "fa-lightbulb", message: "No feature requests surfaced yet." %>
              <% end %>
            </section>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyze_controller_test.rb -n "/feature request tiles/"`
Expected: PASS

- [ ] **Step 6: Run the full analyze controller test file**

Run: `bin/rails test test/controllers/analyze_controller_test.rb`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add app/views/analyze/_feature_request.html.erb app/views/analyze/show.html.erb test/controllers/analyze_controller_test.rb
git commit -m "Apply Patterns tile treatment to Feature requests"
```

---

### Task 5: Tile styling — bold title, chevron rotation, quote tag

**Files:**
- Modify: `app/assets/stylesheets/pages/_analysis.scss`

**Interfaces:**
- Consumes: `.analysis-tile`, `.analysis-tile__summary`, `.analysis-tile__title`, `.analysis-tile__chevron`, `.analysis-tile__body`, `.analysis-quote-tag`, `.analysis-quote-tag__link` — all the class names introduced by Tasks 3/4's ERB, which is why this task comes last (the markup must exist first to eyeball the result against).
- Produces: no new classes for later tasks to consume — this is a leaf/styling task.

- [ ] **Step 1: Add the tile styles**

Append to `app/assets/stylesheets/pages/_analysis.scss` (after the existing `.analysis-card--tall` rule, so tile styles sit next to the base card styles they extend):

```scss
.analysis-tile {
  cursor: pointer;
}

.analysis-tile__summary {
  cursor: pointer;
  list-style: none;
}

.analysis-tile__summary::-webkit-details-marker {
  display: none;
}

.analysis-tile__title {
  font-size: $font-size-lg;
  font-weight: 700;
}

.analysis-tile__chevron {
  color: var(--color-text-muted);
  transition: transform $transition-base $transition-easing;
}

.analysis-tile[open] .analysis-tile__chevron {
  transform: rotate(180deg);
}

.analysis-tile__body {
  border-top: 1px solid var(--color-border-subtle);
  padding-top: $space-3;
}

.analysis-quote-tag {
  align-items: center;
  color: var(--color-text-muted);
  display: flex;
  font-size: $font-size-sm;
  gap: $space-2;
}

.analysis-quote-tag__link {
  color: inherit;
  text-decoration: underline;
}
```

Before writing this, verify `$transition-base`/`$transition-easing` exist (they're already referenced by `.analysis-tabs .nav-link` earlier in this same file, so they're in scope):

Run: `grep -n "transition-base\|transition-easing" app/assets/stylesheets/config/_design_tokens.scss`
Expected: both defined — reuse them rather than introducing new transition values.

- [ ] **Step 2: Verify the app boots and assets compile**

Run: `bin/rails runner "true"` (loads the app, including asset pipeline config, without booting a server)
Expected: no errors. This does not compile SCSS itself, so also start the dev server briefly:

Run: `bin/dev &` then `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000` after a few seconds, then stop the server.
Expected: `200` or a redirect code (e.g. `302` to sign-in) — not a 500, which would indicate a SCSS syntax error.

- [ ] **Step 3: Manually verify in the browser**

Since collapse/expand is native browser behavior (no JS to unit test) and there's no `test/system` directory in this project (confirmed absent — this is a controller/asset-only change, not a gap to fill in as part of this task), verify by hand:
1. Sign in, open a loop's Analyze page that has at least one theme and one feature request with quotes.
2. Confirm both sections render as a 2-column grid (1 column if you narrow the browser below Bootstrap's `md` breakpoint).
3. Confirm each tile is collapsed by default, showing bold title + sentiment/count badges (themes only) + description.
4. Click a tile; confirm it expands independently (other tiles stay collapsed) and shows its quotes with "Interview #N" + that quote's own sentiment badge.
5. Click an "Interview #N" link; confirm it navigates to the Analyze page with the range widened to that interview's day and scrolls to the corresponding response card.

- [ ] **Step 4: Run rubocop and the full test suite**

Run: `bin/rubocop app/controllers/analyze_controller.rb app/helpers/analyze_helper.rb app/views/analyze/`
Expected: no new offenses (existing pre-existing offenses in `analyze_controller.rb`, per `CLAUDE.md`, are not this task's concern — only check nothing *new* was introduced)

Run: `bin/rails test`
Expected: all PASS except the pre-existing, unrelated `PagesControllerTest` failure documented in `CLAUDE.md` ("bin/ci is currently RED on master, and it is not your change")

- [ ] **Step 5: Commit**

```bash
git add app/assets/stylesheets/pages/_analysis.scss
git commit -m "Style Patterns/feature-request tiles: bold title, chevron, quote tags"
```

---

## Self-Review Notes

- **Spec coverage:** headline rename (Task 3), tile visuals/bold title (Task 5), 2-col grid both sections (Tasks 3/4), collapsible `<details>`/`<summary>` (Tasks 3/4), interview tag + per-quote sentiment + range-widening link (Tasks 1/2), same treatment for feature requests (Task 4), no new JS (verified throughout), token-only SCSS (Task 5, step 1 verifies token existence before use). All spec sections have a corresponding task.
- **Placeholder scan:** no TBD/TODO; every step has literal file paths, full code blocks, and exact run commands with expected output.
- **Type consistency:** `interview_numbers` is a `Hash` (`feedback.id => Integer`) everywhere it's threaded through — controller (Task 1) → helper argument (Task 2) → partial locals (Tasks 3/4). `interview_tag_link(loop_record, feedback, interview_numbers)` signature is identical across its Task 2 definition and Task 3/4 call sites. `.analysis-card` is kept on the tile root in both partials so the pre-existing `analysis_controller_test.rb:29-30` assertions keep passing.
