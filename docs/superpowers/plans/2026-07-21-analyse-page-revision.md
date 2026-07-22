# Analyse Page Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Analyse per-loop view trustworthy and intuitive — Refresh visibly regenerates the insight, per-interview themes/requests are visible, and the page reads as a guided story.

**Architecture:** Split the per-interview work by cost (ElevenLabs supplies title/summary for free at ingestion; the Stage-1 LLM job does extraction only). Make Refresh a synchronous, single-LLM-call Stage-2 rollup with a spinner and real error flash. Add an async backfill path for stragglers. Restructure the per-loop view with explainers, empty states, and per-feedback chips. Fix seeds so a replant demonstrates the feature.

**Tech Stack:** Rails 8.1, PostgreSQL (jsonb), Minitest, `ruby-openai`, Bootstrap 5.3, Turbo/Stimulus, Solid Queue.

## Global Constraints

- Ruby 3.3.9, Rails 8.1, Minitest only. No mocking gem — stub at a seam with `stub_instance_method(klass, name, replacement) { ... }` from `test/test_helper.rb`, or inject a fake collaborator (see `FeedbackAnalyzerTest`).
- **Heroku kills any request > 30s.** A synchronous controller action must make **at most one** LLM call.
- Scope every controller query through `current_organization` (this codebase's ownership seam — see `AnalyseController`), never `current_user`.
- `Feedback::SENTIMENT_VALUES = %w[excited positive neutral frustrated negative]`. Reuse `sentiment_badge` / `AnalyseHelper` for sentiment UI.
- Analyzed vs pending is defined by the jsonb default: analyzed = `where.not(extracted_points: {})`, pending = `where(extracted_points: {})`. `extracted_points` is `default: {}, null: false`.
- Keep methods short (RuboCop `Metrics/MethodLength` max 10, `Metrics/ClassLength` max 100). Run `bin/rubocop` before each commit; add no new offenses.
- Do not "fix" the OpenAI model id or request shape blindly — verify any request-body change against the live API (Task 1).
- `bin/ci` baseline is RED on master (`PagesControllerTest` stale 302) — confirm any failure is ours before chasing it.

---

### Task 1: LlmClient — configurable model + reasoning_effort

**Files:**
- Modify: `app/services/llm_client.rb`
- Test: `test/services/llm_client_test.rb`

**Interfaces:**
- Produces: `LlmClient::MODEL` (from `ENV["OPENAI_MODEL"]`, default `"gpt-5-mini"`), `LlmClient::REASONING_EFFORT` (from `ENV["OPENAI_REASONING_EFFORT"]`, default `"low"`). `#complete(system:, user:, schema:)` unchanged in signature; request body now carries `reasoning_effort`.

- [ ] **Step 1: Write the failing test** — append to `test/services/llm_client_test.rb`:

```ruby
  test "request body includes the configured model and reasoning effort" do
    captured = nil
    recorder = Class.new do
      define_method(:initialize) { |sink| @sink = sink }
      define_method(:chat) { |parameters:| @sink.call(parameters); { "choices" => [{ "message" => { "content" => "{}" } }] } }
    end
    client = LlmClient.new(client: recorder.new(->(p) { captured = p }))
    client.complete(system: "s", user: "u", schema: {})

    assert_equal LlmClient::MODEL, captured[:model]
    assert_equal LlmClient::REASONING_EFFORT, captured[:reasoning_effort]
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/llm_client_test.rb`
Expected: FAIL — `captured[:reasoning_effort]` is `nil`.

- [ ] **Step 3: Implement** — edit `app/services/llm_client.rb`:

```ruby
class LlmClient
  MODEL = ENV.fetch("OPENAI_MODEL", "gpt-5-mini")
  REASONING_EFFORT = ENV.fetch("OPENAI_REASONING_EFFORT", "low")

  class Error < StandardError; end

  def initialize(client: OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil)))
    @client = client
  end

  def complete(system:, user:, schema:)
    response = @client.chat(parameters: body(system, user, schema))
    extract(response)
  rescue StandardError => e
    raise Error, "OpenAI request failed: #{e.message}"
  end

  private

  def body(system, user, schema)
    {
      model: MODEL,
      reasoning_effort: REASONING_EFFORT,
      messages: [{ role: "system", content: system }, { role: "user", content: user }],
      response_format: { type: "json_schema", json_schema: { name: "analysis", schema: schema, strict: true } }
    }
  end

  def extract(response)
    raise Error, response.dig("error", "message") if response["error"]

    JSON.parse(response.dig("choices", 0, "message", "content"))
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/llm_client_test.rb`
Expected: PASS (all three).

- [ ] **Step 5: Verify against the live API** (guards the load-bearing request shape)

Run: `bin/rails runner 'puts LlmClient.new.complete(system: "Reply in JSON.", user: "Say hi.", schema: {type: "object", additionalProperties: false, required: ["msg"], properties: {msg: {type: "string"}}}).inspect'`
Expected: prints a Hash like `{"msg"=>"hi"}`. If it raises `LlmClient::Error` mentioning an unsupported/`reasoning_effort` parameter, remove `reasoning_effort:` from `body` (and the two assertions added in Step 1), note the finding in the commit message, and re-run Step 4. Otherwise leave it in.

- [ ] **Step 6: Commit**

```bash
bin/rubocop app/services/llm_client.rb
git add app/services/llm_client.rb test/services/llm_client_test.rb
git commit -m "LlmClient: ENV-configurable model + reasoning_effort for latency"
```

---

### Task 2: ElevenLabsWebhookPayload — free title + summary

**Files:**
- Modify: `app/services/eleven_labs_webhook_payload.rb`
- Test: `test/services/eleven_labs_webhook_payload_test.rb`

**Interfaces:**
- Produces: `ElevenLabsWebhookPayload#summary_title` → `data.analysis.call_summary_title` (or `nil`); `#transcript_summary` → `data.analysis.transcript_summary` (or `nil`).

- [ ] **Step 1: Write the failing test** — append to `test/services/eleven_labs_webhook_payload_test.rb`:

```ruby
  test "exposes the summary title and transcript summary from analysis" do
    raw = file_fixture("elevenlabs_post_call_transcription.json").read
    payload = ElevenLabsWebhookPayload.new(raw)

    assert_equal "Onboarding Feedback", payload.summary_title
    assert payload.transcript_summary.to_s.start_with?("The user provided feedback")
  end

  test "title and summary degrade to nil on a malformed body" do
    payload = ElevenLabsWebhookPayload.new("not json")

    assert_nil payload.summary_title
    assert_nil payload.transcript_summary
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/eleven_labs_webhook_payload_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'summary_title'`.

- [ ] **Step 3: Implement** — in `app/services/eleven_labs_webhook_payload.rb`, add public methods after `sentiment_rationale` (before `private`):

```ruby
  def summary_title
    analysis["call_summary_title"]
  end

  def transcript_summary
    analysis["transcript_summary"]
  end
```

(`analysis` already exists as a private method returning `data["analysis"] || {}`, so both degrade to `nil` on a malformed/short payload.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/eleven_labs_webhook_payload_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/services/eleven_labs_webhook_payload.rb
git add app/services/eleven_labs_webhook_payload.rb test/services/eleven_labs_webhook_payload_test.rb
git commit -m "ElevenLabsWebhookPayload: expose summary_title + transcript_summary"
```

---

### Task 3: Webhook ingestion writes title + summary

**Files:**
- Modify: `app/controllers/eleven_labs_webhooks_controller.rb:54-61` (`feedback_attributes`)
- Test: `test/controllers/eleven_labs_webhooks_controller_test.rb`

**Interfaces:**
- Consumes: `ElevenLabsWebhookPayload#summary_title`, `#transcript_summary` (Task 2).
- Produces: ingested `Feedback` rows carry `title` + `summary` with no LLM call.

- [ ] **Step 1: Write the failing test** — add to `test/controllers/eleven_labs_webhooks_controller_test.rb` (follow the existing signed-request helper in that file; if the file posts a valid signed body already, mirror that setup):

```ruby
  test "ingested feedback carries the ElevenLabs title and summary" do
    raw = file_fixture("elevenlabs_post_call_transcription.json").read
    Loop.create!(name: "Ingest", user: users_founder, agent_id: JSON.parse(raw).dig("data", "agent_id"))

    stub_instance_method(ElevenLabsSignatureVerifier, :valid?, ->(*) { true }) do
      post eleven_labs_webhook_path, body: raw, headers: { "CONTENT_TYPE" => "application/json" }
    end

    feedback = Feedback.order(:created_at).last
    assert_equal "Onboarding Feedback", feedback.title
    assert feedback.summary.to_s.start_with?("The user provided feedback")
  end
```

If the existing test file already defines a founder/user helper and a signing helper, reuse those names instead of `users_founder`; check the top of the file first.

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/eleven_labs_webhooks_controller_test.rb`
Expected: FAIL — `feedback.title` is `nil`.

- [ ] **Step 3: Implement** — edit `feedback_attributes` in `app/controllers/eleven_labs_webhooks_controller.rb`:

```ruby
  def feedback_attributes
    {
      conversation_id: payload.conversation_id,
      transcript: payload.transcript,
      sentiment: payload.sentiment,
      sentiment_rationale: payload.sentiment_rationale,
      title: payload.summary_title,
      summary: payload.transcript_summary
    }
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/eleven_labs_webhooks_controller_test.rb`
Expected: PASS (new test + existing ones).

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/controllers/eleven_labs_webhooks_controller.rb
git add app/controllers/eleven_labs_webhooks_controller.rb test/controllers/eleven_labs_webhooks_controller_test.rb
git commit -m "Webhook: write feedback title/summary from ElevenLabs (no LLM)"
```

---

### Task 4: FeedbackAnalyzer — extraction only

**Files:**
- Modify: `app/services/feedback_analyzer.rb`
- Test: `test/services/feedback_analyzer_test.rb`

**Interfaces:**
- Produces: `FeedbackAnalyzer#call` writes only `extracted_points` (`{"points" => [...]}`); leaves `title`/`summary` untouched. Schema/prompt request `points` only.

- [ ] **Step 1: Rewrite the tests** — replace the body of `test/services/feedback_analyzer_test.rb` with:

```ruby
require "test_helper"

class FeedbackAnalyzerTest < ActiveSupport::TestCase
  Stub = Struct.new(:payload) { def complete(**) = payload }

  test "writes extracted points and preserves the existing title and summary" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    feedback = Feedback.create!(loop: loop_record, transcript: "I felt overwhelmed", title: "From EL", summary: "EL summary")
    payload = { "points" => [{ "kind" => "request", "title" => "Guided walkthrough", "quote" => "a run-through agent would help" }] }

    FeedbackAnalyzer.new(feedback, client: Stub.new(payload)).call

    feedback.reload
    assert_equal "a run-through agent would help", feedback.extracted_points["points"].first["quote"]
    assert_equal "From EL", feedback.title
    assert_equal "EL summary", feedback.summary
  end

  test "degrades gracefully when the LLM fails" do
    founder = User.create!(email: "founder@example.com", password: "password123")
    loop_record = Loop.create!(name: "L", user: founder)
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    failing = Object.new
    def failing.complete(**) = raise(LlmClient::Error, "boom")

    FeedbackAnalyzer.new(feedback, client: failing).call

    assert_equal({}, feedback.reload.extracted_points)
  end
end
```

- [ ] **Step 2: Run tests to verify the first fails**

Run: `bin/rails test test/services/feedback_analyzer_test.rb`
Expected: FAIL — current analyzer references `result["title"]`/`result["summary"]` and overwrites title.

- [ ] **Step 3: Implement** — replace `app/services/feedback_analyzer.rb`:

```ruby
class FeedbackAnalyzer
  SYSTEM = <<~PROMPT.freeze
    You analyze a single user feedback interview transcript.
    Return `points`, a list of the specific themes and feature requests the respondent
    raised. For every point, copy a `quote` VERBATIM from the transcript — never paraphrase.
    `kind` is "theme" or "request".
  PROMPT

  SCHEMA = {
    type: "object", additionalProperties: false, required: %w[points],
    properties: {
      points: {
        type: "array",
        items: {
          type: "object", additionalProperties: false, required: %w[kind title quote],
          properties: {
            kind: { type: "string", enum: %w[theme request] },
            title: { type: "string" },
            quote: { type: "string" }
          }
        }
      }
    }
  }.freeze

  def initialize(feedback, client: LlmClient.new)
    @feedback = feedback
    @client = client
  end

  def call
    result = @client.complete(system: SYSTEM, user: @feedback.transcript.to_s, schema: SCHEMA)
    @feedback.update!(extracted_points: { "points" => result["points"] })
  rescue LlmClient::Error => e
    Rails.logger.warn("[FeedbackAnalyzer] feedback=#{@feedback.id} failed: #{e.message}")
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/feedback_analyzer_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/services/feedback_analyzer.rb
git add app/services/feedback_analyzer.rb test/services/feedback_analyzer_test.rb
git commit -m "FeedbackAnalyzer: extraction only (title/summary now from ElevenLabs)"
```

---

### Task 5: Loop#feedbacks_pending_extraction

**Files:**
- Modify: `app/models/loop.rb:43-45`
- Test: `test/models/loop_test.rb`

**Interfaces:**
- Produces: `Loop#feedbacks_pending_extraction` → relation of feedbacks with empty `extracted_points`; `Loop#pending_extraction_count` → its size.

- [ ] **Step 1: Write the failing test** — add to `test/models/loop_test.rb`:

```ruby
  test "feedbacks_pending_extraction returns only feedbacks without extracted points" do
    founder = User.create!(email: "pend@example.com", password: "password123")
    loop_record = Loop.create!(name: "Pending", user: founder)
    analyzed = Feedback.create!(loop: loop_record, transcript: "a", extracted_points: { "points" => [{ "kind" => "theme", "title" => "t", "quote" => "q" }] })
    pending = Feedback.create!(loop: loop_record, transcript: "b")

    assert_includes loop_record.feedbacks_pending_extraction, pending
    assert_not_includes loop_record.feedbacks_pending_extraction, analyzed
    assert_equal 1, loop_record.pending_extraction_count
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/loop_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'feedbacks_pending_extraction'`.

- [ ] **Step 3: Implement** — in `app/models/loop.rb`, add after `unanalyzed_feedback_count`:

```ruby
  def feedbacks_pending_extraction
    feedbacks.where(extracted_points: {})
  end

  def pending_extraction_count
    feedbacks_pending_extraction.size
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/loop_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/models/loop.rb
git add app/models/loop.rb test/models/loop_test.rb
git commit -m "Loop: feedbacks_pending_extraction for the backfill nudge"
```

---

### Task 6: Synchronous Stage-2-only Refresh

**Files:**
- Modify: `app/controllers/analyse_controller.rb:21-25` (`refresh`)
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `LoopAnalyzer`, `LoopInsightWriter` (existing), `LlmClient::Error`.
- Produces: `POST /analyse/:slug/refresh` runs the rollup inline and redirects with a success flash; on `LlmClient::Error` redirects with an alert flash. No `perform_later`.

- [ ] **Step 1: Write the failing tests** — add to `test/controllers/analyse_controller_test.rb` (reuse the file's existing sign-in + loop setup helpers; check the top of the file for the fixture/login pattern and a feedback with `extracted_points`):

```ruby
  test "refresh regenerates the insight synchronously and flashes success" do
    loop_record = analysable_loop_with_points # helper defined below or existing setup
    fake = { "overall_sentiment" => "positive", "summary" => "Trending up", "themes" => [], "feature_requests" => [] }

    stub_instance_method(LlmClient, :complete, ->(**) { fake }) do
      post refresh_analyse_path(loop_record.slug)
    end

    assert_redirected_to analyse_path(loop_record.slug)
    assert_equal "positive", loop_record.reload.insight.overall_sentiment
  end

  test "refresh flashes an error when the LLM fails" do
    loop_record = analysable_loop_with_points

    stub_instance_method(LlmClient, :complete, ->(**) { raise LlmClient::Error, "boom" }) do
      post refresh_analyse_path(loop_record.slug)
    end

    assert_redirected_to analyse_path(loop_record.slug)
    assert_match(/couldn.t|failed|try again/i, flash[:alert])
  end
```

If `analysable_loop_with_points` does not already exist, add a private helper in the test class that creates a signed-in user's org loop with one feedback whose `extracted_points` is `{ "points" => [{ "kind" => "theme", "title" => "t", "quote" => "q" }] }`, matching the login pattern already used elsewhere in this file.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: FAIL — current `refresh` enqueues a job and never writes the insight in-request.

- [ ] **Step 3: Implement** — replace `refresh` in `app/controllers/analyse_controller.rb`:

```ruby
  def refresh
    loop_record = current_organization.loops.find_by!(slug: params[:slug])
    analyzer = LoopAnalyzer.new(loop_record)
    LoopInsightWriter.new(loop_record, analyzer.call, analyzer.analyzed_count).call
    redirect_to analyse_path(loop_record.slug), notice: "Analysis updated."
  rescue LlmClient::Error => e
    Rails.logger.warn("[AnalyseController#refresh] #{e.message}")
    redirect_to analyse_path(loop_record.slug), alert: "We couldn't generate the analysis just now — please try again."
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/controllers/analyse_controller.rb
git add app/controllers/analyse_controller.rb test/controllers/analyse_controller_test.rb
git commit -m "AnalyseController#refresh: synchronous Stage-2 rollup with error flash"
```

---

### Task 7: Backfill action for stragglers

**Files:**
- Modify: `config/routes.rb:48` (add backfill route after refresh)
- Modify: `app/controllers/analyse_controller.rb` (add `backfill`)
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `Loop#feedbacks_pending_extraction` (Task 5), `AnalyzeFeedbackJob` (existing).
- Produces: `POST /analyse/:slug/backfill` (`backfill_analyse_path`) enqueues one `AnalyzeFeedbackJob` per pending feedback (async), redirects with a notice; enqueues none when nothing is pending.

- [ ] **Step 1: Write the failing test** — add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "backfill enqueues one Stage 1 job per pending feedback" do
    loop_record = analysable_loop_with_points
    Feedback.create!(loop: loop_record, transcript: "unanalyzed one")

    assert_enqueued_jobs 1, only: AnalyzeFeedbackJob do
      post backfill_analyse_path(loop_record.slug)
    end
    assert_redirected_to analyse_path(loop_record.slug)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: FAIL — `undefined method 'backfill_analyse_path'` / no route.

- [ ] **Step 3: Add the route** — in `config/routes.rb`, directly after the refresh line (`post "analyse/:slug/refresh"...`):

```ruby
  post "analyse/:slug/backfill", to: "analyse#backfill", as: :backfill_analyse
```

- [ ] **Step 4: Implement the action** — add to `app/controllers/analyse_controller.rb` (public, after `refresh`):

```ruby
  def backfill
    loop_record = current_organization.loops.find_by!(slug: params[:slug])
    pending = loop_record.feedbacks_pending_extraction
    pending.find_each { |feedback| AnalyzeFeedbackJob.perform_later(feedback) }
    redirect_to analyse_path(loop_record.slug),
                notice: "Analyzing #{pending.size} #{'response'.pluralize(pending.size)} in the background — Refresh when it's done."
  end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
bin/rubocop app/controllers/analyse_controller.rb
git add config/routes.rb app/controllers/analyse_controller.rb test/controllers/analyse_controller_test.rb
git commit -m "AnalyseController#backfill: async Stage-1 for straggler feedback"
```

---

### Task 8: Insight panel — hero, nudge, spinner

**Files:**
- Modify: `app/views/analyse/_insight_panel.html.erb`

(No SCSS change needed — the partial reuses the existing `analysis-summary-card` class and Bootstrap 5.3 utilities, including the `-subtle`/`-emphasis` pairings.)

**Interfaces:**
- Consumes: `loop_record.insight`, `loop_record.pending_extraction_count` (Task 5), `backfill_analyse_path`, `refresh_analyse_path`.

- [ ] **Step 1: Rewrite the partial** — replace `app/views/analyse/_insight_panel.html.erb`:

```erb
<div class="analysis-summary-card h-100 p-4">
  <div class="d-flex justify-content-between align-items-start mb-2 gap-3">
    <div>
      <h2 class="h5 mb-1">What people are telling you</h2>
      <p class="text-muted small mb-0">The headline across every interview in this loop. Press Refresh after new responses come in.</p>
    </div>
    <%= button_to refresh_analyse_path(loop_record.slug),
                  class: "btn btn-primary text-nowrap",
                  data: { turbo_submits_with: "Analyzing…" } do %>
      <i class="fa-solid fa-arrows-rotate me-1"></i>Refresh
    <% end %>
  </div>

  <% if loop_record.insight.present? %>
    <div class="mb-2"><%= sentiment_badge(loop_record.insight.overall_sentiment) %></div>
    <p class="mb-2"><%= loop_record.insight.summary %></p>
    <p class="text-muted small mb-0">
      <%= pluralize(loop_record.insight.analyzed_feedback_count, "interview") %> analyzed
      <% if loop_record.unanalyzed_feedback_count.positive? %>
        · <%= pluralize(loop_record.unanalyzed_feedback_count, "new response") %> since — Refresh to include them
      <% end %>
    </p>
  <% else %>
    <p class="text-muted mb-0">No analysis yet. Once you've collected a few interviews, press <strong>Refresh</strong> to see the themes and requests.</p>
  <% end %>

  <% if loop_record.pending_extraction_count.positive? %>
    <div class="alert alert-warning d-flex justify-content-between align-items-center gap-2 mt-3 mb-0 py-2">
      <span class="small mb-0">
        <%= pluralize(loop_record.pending_extraction_count, "response") %> haven't been analyzed yet.
      </span>
      <%= button_to "Analyze them", backfill_analyse_path(loop_record.slug),
                    class: "btn btn-sm btn-outline-dark text-nowrap",
                    data: { turbo_submits_with: "Starting…" } %>
    </div>
  <% end %>
</div>
```

(`data: { turbo_submits_with: ... }` is Turbo's built-in submit-label swap — the button shows the busy label and is disabled while the synchronous request runs, no custom JS needed.)

- [ ] **Step 2: Manually verify the render** (view-only; no unit test)

Run: `bin/rails runner 'l = Loop.joins(:feedbacks).first; puts ApplicationController.render(partial: "analyse/insight_panel", locals: { loop_record: l }).include?("Refresh")'`
Expected: prints `true`. If it errors on a missing helper/route, fix the reference before continuing.

- [ ] **Step 3: Commit**

```bash
git add app/views/analyse/_insight_panel.html.erb
git commit -m "Analyse: insight hero with refresh spinner + backfill nudge"
```

---

### Task 9: Per-feedback chips + guided-story sections

**Files:**
- Modify: `app/views/analyse/show.html.erb` (per_loop pane: section explainers, empty states, per-feedback chips)
- Create: `app/views/analyse/_extracted_points.html.erb`

**Interfaces:**
- Consumes: `feedback.extracted_points` (`{"points" => [{ "kind", "title", "quote" }]}`).

- [ ] **Step 1: Create the chips partial** — `app/views/analyse/_extracted_points.html.erb`:

```erb
<% points = Array(feedback.extracted_points["points"]) %>
<% if points.any? %>
  <div class="d-flex flex-wrap gap-1 mt-2">
    <% points.each do |point| %>
      <% theme = point["kind"] == "theme" %>
      <span class="badge rounded-pill <%= theme ? "text-bg-info-subtle text-info-emphasis" : "text-bg-primary-subtle text-primary-emphasis" %>">
        <i class="fa-solid <%= theme ? "fa-tag" : "fa-lightbulb" %> me-1"></i><%= point["title"] %>
      </span>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 2: Add section explainers + empty states** — in `app/views/analyse/show.html.erb`, replace the Themes/Feature-requests block (currently lines ~207-221) with:

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

- [ ] **Step 3: Add a heading + explainer to the raw feedback list** — replace the `<h3 class="mb-3">Feedback</h3>` line (~223) with:

```erb
        <h3 class="mb-1">Every response</h3>
        <p class="text-muted small mb-3">Each interview in full. Chips show the themes and requests we pulled from that one conversation.</p>
```

- [ ] **Step 4: Render chips on each feedback card** — in the feedback loop of `show.html.erb`, add immediately after the `<% end %>` that closes the summary/transcript `if/else` (after the transcript block, before the `sentiment_rationale` block):

```erb
                <%= render "extracted_points", feedback: feedback %>
```

- [ ] **Step 5: Manually verify the render**

Run: `bin/rails runner 'puts ApplicationController.render(template: "analyse/show", assigns: {}) rescue puts "needs request context — verify in browser"'`
Then start the server (`bin/dev`), visit `/analyse/<slug>` for a seeded loop, and confirm: section explainers appear, empty states show for a loop with no insight, and a feedback with `extracted_points` shows chips.
Expected: chips render as pills; sections have descriptions.

- [ ] **Step 6: Commit**

```bash
git add app/views/analyse/show.html.erb app/views/analyse/_extracted_points.html.erb
git commit -m "Analyse: guided-story sections, explainers, and per-feedback chips"
```

---

### Task 10: Seeds — accurate analysis layer

**Files:**
- Modify: `db/seeds.rb` (the analysis-layer helpers around lines 80-120 and the `annotate`/insight blocks from line ~466)

**Interfaces:**
- Produces: seeded annotated feedback carries `title` + `summary`; each seeded `Insight.analyzed_feedback_count` equals its loop's `where.not(extracted_points: {}).count`.

- [ ] **Step 1: Set title/summary on annotated feedback** — in the seed helper that writes `extracted_points` (the block near line 88 that sets `extracted_points: { "points" => ... }`), also set `title` and `summary` on that feedback. Locate the helper (it receives an `annotation`/`feedback`) and add, alongside the `extracted_points` assignment:

```ruby
      feedback.update!(
        title: annotation[:title],
        summary: annotation[:summary],
        extracted_points: { "points" => annotation[:points].map { |point| point.transform_keys(&:to_s) } }
      )
```

Then add a `title:` and `summary:` (one short realistic sentence each) to each annotation hash in the seed data literals. Match the tone of the existing quotes.

- [ ] **Step 2: Make analyzed_feedback_count truthful** — in the insight-creation block (near line 104, `loop_record.create_insight!(...)`), set the count from the data rather than a literal:

```ruby
  insight = loop_record.create_insight!(
    summary: insight_spec[:summary],
    overall_sentiment: insight_spec[:overall_sentiment],
    analyzed_feedback_count: loop_record.feedbacks.where.not(extracted_points: {}).count,
    generated_at: Time.current
  )
```

(Keep the existing `themes`/`feature_requests`/`quotes` creation below it unchanged.)

- [ ] **Step 3: Replant and verify**

Run: `bin/rails db:seed:replant`
Then: `bin/rails runner 'Loop.includes(:insight).each { |l| next unless l.insight; puts "#{l.name}: insight=#{l.insight.analyzed_feedback_count} actual=#{l.feedbacks.where.not(extracted_points: {}).count} pending=#{l.pending_extraction_count}" }'`
Expected: for every loop, `insight` == `actual` (no mismatch); `pending` may be positive (bulk volume feedback) — that's intended and exercises the nudge.

- [ ] **Step 4: Commit**

```bash
git add db/seeds.rb
git commit -m "Seeds: title/summary on annotated feedback + truthful analyzed count"
```

---

### Task 11: Full CI + live smoke

- [ ] **Step 1: Run the suite**

Run: `bin/rails test`
Expected: green except the known-stale `PagesControllerTest#test_signed-in_visitors_can_view_the_landing_page` (302 vs 200) — that pre-exists on master and is not ours.

- [ ] **Step 2: Lint**

Run: `bin/rubocop`
Expected: no *new* offenses (the pre-existing `analyse_controller.rb` offenses noted in CLAUDE.md may remain; do not add to them).

- [ ] **Step 3: Live smoke of the full pipeline**

Run:
```bash
bin/rails runner '
l = Loop.where.not(id: nil).joins(:feedbacks).first
f = l.feedbacks.where(extracted_points: {}).first || l.feedbacks.first
f.update!(extracted_points: {}) if f
FeedbackAnalyzer.new(f).call
puts "stage1 points: #{f.reload.extracted_points["points"]&.size}"
a = LoopAnalyzer.new(l); LoopInsightWriter.new(l, a.call, a.analyzed_count).call
puts "stage2 insight themes: #{l.reload.insight.themes.size} sentiment: #{l.insight.overall_sentiment}"
'
```
Expected: prints a non-nil Stage-1 point count and a regenerated Stage-2 insight, both within a few seconds (confirming `reasoning_effort` latency is acceptable). If it raises an `insufficient_quota` `LlmClient::Error`, that's an OpenAI billing state, not a code bug — note it and stop.

- [ ] **Step 4: Final commit (if any lint fixups)**

```bash
git add -A
git commit -m "Analyse revision: CI + smoke verification"
```
