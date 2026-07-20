# Feedback Analysis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Analyse tab into a tool that reads deep insight out of interview transcripts — per-interview narrative summaries, and a loop-level thematic rollup (themes + feature requests) that surfaces concrete product-improvement signal.

**Architecture:** Two-stage, extract-then-cluster pipeline. Stage 1 runs once per interview at ingestion: an LLM extracts a narrative summary, a title, and structured points (candidate themes/requests + verbatim quotes) onto the `Feedback`. Stage 2 runs on demand per loop: an LLM clusters those already-extracted points (never re-reading transcripts) into `Theme` and `FeatureRequest` rows, each linked back to the interviews that evidence it via a polymorphic `Quote`, plus a loop-level `Insight`. All LLM calls go through one swappable `LlmClient` seam backed by OpenAI GPT-5 mini.

**Tech Stack:** Rails 8.1, PostgreSQL, Solid Queue (jobs), `ruby-openai` gem, Minitest, Bootstrap 5.3 + Turbo/Stimulus.

**Design doc:** `docs/superpowers/specs/2026-07-20-feedback-analysis-design.md`

## Global Constraints

- Ruby 3.3.9, Rails 8.1, PostgreSQL. Use `bin/` wrappers.
- Rubocop (custom `.rubocop.yml`): `Metrics/MethodLength` max **10**, `Metrics/ClassLength` max **100**, line length **120**. `test/` is excluded from rubocop. Add **no new offenses**; run `bin/rubocop` before each commit.
- Tests are Minitest. **No mocking gem** — stub at a seam with `stub_instance_method(klass, name, replacement) { ... }` from `test/test_helper.rb`. Never hit the real OpenAI API in tests.
- **This repo has NO fixtures.** Tests create data inline. A user: `User.create!(email: "founder@example.com", password: "password123")` (use distinct emails within a test). Controller/integration tests `include Devise::Test::IntegrationHelpers` and `sign_in <user>` in `setup`. **Any test snippet in this plan that shows `users(:founder)` or `sign_in users(:founder)` is shorthand — replace it with an inline-created user following this convention, keeping the test's intent identical.** `test/controllers/analyse_controller_test.rb` does not exist yet; create it (with the Devise helper + a signed-in user in `setup`) the first time a task adds to it.
- Ownership is by workspace: scope through `current_workspace_owner`, never `current_user`.
- Transcripts are **respondent PII** — never log them; send only transcript text to the LLM, never respondent identity.
- LLM model id: `gpt-5-mini`, reachable only through the `LlmClient` seam (one-line provider swap). API key via `ENV["OPENAI_API_KEY"]`.
- Sentiment vocabulary is `Feedback::SENTIMENT_VALUES` (`%w[excited positive neutral frustrated negative]`) — the single source of truth for any sentiment field.
- After any migration, confirm `grep nextval db/schema.rb` is empty (Postgres sequence gotcha).
- Run `bin/ci` before considering the feature done (note the pre-existing red `PagesControllerTest` baseline — a failure there is not yours).

---

### Task 1: Enrich `Feedback` and `Insight` with analysis columns

**Files:**
- Create: `db/migrate/<ts>_add_analysis_columns_to_feedbacks.rb`
- Create: `db/migrate/<ts>_add_analysis_columns_to_insights.rb`
- Modify: `app/models/feedback.rb`
- Modify: `app/models/insight.rb`
- Test: `test/models/feedback_test.rb`, `test/models/insight_test.rb`

**Interfaces:**
- Produces: `Feedback#title` (string), `Feedback#summary` (text), `Feedback#extracted_points` (jsonb, default `{}`); `Insight#overall_sentiment` (string), `Insight#analyzed_feedback_count` (integer, default 0), `Insight#generated_at` (datetime). `Insight has_many :themes, :feature_requests` (declared here, tables added in Task 2).

- [ ] **Step 1: Write the failing test**

In `test/models/feedback_test.rb`:

```ruby
require "test_helper"

class FeedbackTest < ActiveSupport::TestCase
  test "stores analysis columns" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    feedback = Feedback.create!(
      loop: loop_record, transcript: "hi",
      title: "First week", summary: "Felt overwhelmed",
      extracted_points: { "points" => [{ "kind" => "theme", "title" => "Onboarding", "quote" => "too many features" }] }
    )
    assert_equal "First week", feedback.reload.title
    assert_equal "too many features", feedback.extracted_points["points"].first["quote"]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/feedback_test.rb`
Expected: FAIL — `unknown attribute 'title'`.

- [ ] **Step 3: Write the migrations**

`db/migrate/<ts>_add_analysis_columns_to_feedbacks.rb`:

```ruby
class AddAnalysisColumnsToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :title, :string
    add_column :feedbacks, :summary, :text
    add_column :feedbacks, :extracted_points, :jsonb, default: {}, null: false
  end
end
```

`db/migrate/<ts>_add_analysis_columns_to_insights.rb`:

```ruby
class AddAnalysisColumnsToInsights < ActiveRecord::Migration[8.1]
  def change
    add_column :insights, :overall_sentiment, :string
    add_column :insights, :analyzed_feedback_count, :integer, default: 0, null: false
    add_column :insights, :generated_at, :datetime
  end
end
```

- [ ] **Step 4: Declare the associations**

In `app/models/insight.rb`:

```ruby
class Insight < ApplicationRecord
  belongs_to :loop
  has_many :themes, dependent: :destroy
  has_many :feature_requests, dependent: :destroy
end
```

`app/models/feedback.rb` needs no change yet (columns are auto-attributes); the `has_many :quotes` is added in Task 2.

- [ ] **Step 5: Migrate and run tests**

Run: `bin/rails db:migrate && bin/rails test test/models/feedback_test.rb test/models/insight_test.rb`
Expected: PASS. Then run `grep nextval db/schema.rb` — expected: no output.

- [ ] **Step 6: Commit**

```bash
bin/rubocop app/models/insight.rb
git add db/migrate app/models/insight.rb db/schema.rb test/models
git commit -m "Add analysis columns to feedbacks and insights"
```

---

### Task 2: Add `Theme`, `FeatureRequest`, and the polymorphic `Quote`

**Files:**
- Create: `db/migrate/<ts>_create_themes.rb`, `<ts>_create_feature_requests.rb`, `<ts>_create_quotes.rb`
- Create: `app/models/theme.rb`, `app/models/feature_request.rb`, `app/models/quote.rb`
- Modify: `app/models/feedback.rb` (add `has_many :quotes`)
- Test: `test/models/theme_test.rb`, `test/models/quote_test.rb`

**Interfaces:**
- Consumes: `Insight has_many :themes, :feature_requests` (Task 1).
- Produces: `Theme(insight_id, title, description, mention_count, sentiment)`, `FeatureRequest(insight_id, title, description, status enum, github_issue_url)`, `Quote(quotable [poly], feedback_id, text)`. `Theme#quotes` / `FeatureRequest#quotes` (as `:quotable`); `Feedback#quotes`.

- [ ] **Step 1: Write the failing test**

`test/models/quote_test.rb`:

```ruby
require "test_helper"

class QuoteTest < ActiveSupport::TestCase
  test "quote bridges a theme to the feedback it came from" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    insight = loop_record.create_insight!
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    theme = insight.themes.create!(title: "Onboarding", mention_count: 1)
    quote = theme.quotes.create!(feedback: feedback, text: "too many features")

    assert_equal theme, quote.quotable
    assert_equal [quote], feedback.quotes.to_a
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/quote_test.rb`
Expected: FAIL — `uninitialized constant Quote`.

- [ ] **Step 3: Write the migrations**

`create_themes`:

```ruby
class CreateThemes < ActiveRecord::Migration[8.1]
  def change
    create_table :themes do |t|
      t.references :insight, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :mention_count, default: 0, null: false
      t.string :sentiment
      t.timestamps
    end
  end
end
```

`create_feature_requests`:

```ruby
class CreateFeatureRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_requests do |t|
      t.references :insight, null: false, foreign_key: true
      t.string :title
      t.text :description
      t.integer :status, default: 0, null: false
      t.string :github_issue_url
      t.timestamps
    end
  end
end
```

`create_quotes`:

```ruby
class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :quotable, polymorphic: true, null: false
      t.references :feedback, null: false, foreign_key: true
      t.text :text
      t.timestamps
    end
  end
end
```

- [ ] **Step 4: Write the models**

`app/models/theme.rb`:

```ruby
class Theme < ApplicationRecord
  belongs_to :insight
  has_many :quotes, as: :quotable, dependent: :destroy
end
```

`app/models/feature_request.rb`:

```ruby
class FeatureRequest < ApplicationRecord
  belongs_to :insight
  has_many :quotes, as: :quotable, dependent: :destroy

  enum :status, { open: 0, planned: 1, done: 2, dismissed: 3 }
end
```

`app/models/quote.rb`:

```ruby
class Quote < ApplicationRecord
  belongs_to :quotable, polymorphic: true
  belongs_to :feedback
end
```

Add to `app/models/feedback.rb` (inside the class, after the existing `belongs_to :loop`):

```ruby
  has_many :quotes, dependent: :destroy
```

- [ ] **Step 5: Migrate and run tests**

Run: `bin/rails db:migrate && bin/rails test test/models/quote_test.rb test/models/theme_test.rb`
Expected: PASS. Then `grep nextval db/schema.rb` — expected: no output.

- [ ] **Step 6: Commit**

```bash
bin/rubocop app/models/theme.rb app/models/feature_request.rb app/models/quote.rb app/models/feedback.rb
git add db/migrate app/models db/schema.rb test/models
git commit -m "Add Theme, FeatureRequest, and polymorphic Quote models"
```

---

### Task 3: `LlmClient` — the swappable OpenAI seam

**Files:**
- Modify: `Gemfile` (add `ruby-openai`)
- Create: `app/services/llm_client.rb`
- Test: `test/services/llm_client_test.rb`

**Interfaces:**
- Produces: `LlmClient.new.complete(system:, user:, schema:) -> Hash` (parsed JSON matching `schema`). Raises `LlmClient::Error` on any failure. `LlmClient::MODEL` constant. Constructor takes `client:` (defaults to a real `OpenAI::Client`) so tests inject a stub.

- [ ] **Step 1: Add the gem**

In `Gemfile`, near the other API clients:

```ruby
# OpenAI client for feedback-analysis LLM calls
gem "ruby-openai"
```

Run: `bundle install`
Expected: `ruby-openai` resolves and installs.

- [ ] **Step 2: Write the failing test**

`test/services/llm_client_test.rb`:

```ruby
require "test_helper"

class LlmClientTest < ActiveSupport::TestCase
  class FakeOpenAI
    def initialize(response) = @response = response
    def chat(parameters:) = @response
  end

  test "parses the JSON content from a chat response" do
    body = { "choices" => [{ "message" => { "content" => '{"title":"ok"}' } }] }
    result = LlmClient.new(client: FakeOpenAI.new(body)).complete(system: "s", user: "u", schema: {})
    assert_equal "ok", result["title"]
  end

  test "raises Error when the response carries an error" do
    client = LlmClient.new(client: FakeOpenAI.new({ "error" => { "message" => "boom" } }))
    assert_raises(LlmClient::Error) { client.complete(system: "s", user: "u", schema: {}) }
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/services/llm_client_test.rb`
Expected: FAIL — `uninitialized constant LlmClient`.

- [ ] **Step 4: Write the service**

`app/services/llm_client.rb`:

```ruby
class LlmClient
  MODEL = "gpt-5-mini"

  class Error < StandardError; end

  def initialize(client: OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY", nil)))
    @client = client
  end

  # Returns a Hash parsed from the model's JSON output, validated against `schema`.
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

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/services/llm_client_test.rb`
Expected: PASS (both tests).

- [ ] **Step 6: Commit**

```bash
bin/rubocop app/services/llm_client.rb
git add Gemfile Gemfile.lock app/services/llm_client.rb test/services/llm_client_test.rb
git commit -m "Add LlmClient OpenAI seam for feedback analysis"
```

---

### Task 4: `FeedbackAnalyzer` — Stage 1 per-interview extraction

**Files:**
- Create: `app/services/feedback_analyzer.rb`
- Test: `test/services/feedback_analyzer_test.rb`

**Interfaces:**
- Consumes: `LlmClient#complete` (Task 3), `Feedback#transcript`.
- Produces: `FeedbackAnalyzer.new(feedback, client:).call` — writes `feedback.title`, `feedback.summary`, `feedback.extracted_points`. On `LlmClient::Error`, leaves them nil/`{}` (graceful degradation — the card still renders transcript + sentiment). `FeedbackAnalyzer::SCHEMA` constant (the Stage-1 JSON schema).

- [ ] **Step 1: Write the failing test**

`test/services/feedback_analyzer_test.rb`:

```ruby
require "test_helper"

class FeedbackAnalyzerTest < ActiveSupport::TestCase
  Stub = Struct.new(:payload) { def complete(**) = payload }

  test "writes title, summary, and extracted points onto the feedback" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    feedback = Feedback.create!(loop: loop_record, transcript: "I felt overwhelmed by the features")
    payload = {
      "title" => "First week", "summary" => "Overwhelmed but hopeful",
      "points" => [{ "kind" => "request", "title" => "Guided walkthrough", "quote" => "a run-through agent would help" }]
    }

    FeedbackAnalyzer.new(feedback, client: Stub.new(payload)).call

    assert_equal "First week", feedback.reload.title
    assert_equal "a run-through agent would help", feedback.extracted_points["points"].first["quote"]
  end

  test "degrades gracefully when the LLM fails" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    failing = Object.new
    def failing.complete(**) = raise(LlmClient::Error, "boom")

    FeedbackAnalyzer.new(feedback, client: failing).call

    assert_nil feedback.reload.title
    assert_equal({}, feedback.extracted_points)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/feedback_analyzer_test.rb`
Expected: FAIL — `uninitialized constant FeedbackAnalyzer`.

- [ ] **Step 3: Write the service**

`app/services/feedback_analyzer.rb`:

```ruby
class FeedbackAnalyzer
  SYSTEM = <<~PROMPT.freeze
    You analyze a single user feedback interview transcript.
    Return: a short `title`; a `summary` written as a narrative of the respondent's
    experience and feeling (not a dry abstract); and `points`, a list of the specific
    themes and feature requests they raised. For every point, copy a `quote` VERBATIM
    from the transcript — never paraphrase. `kind` is "theme" or "request".
  PROMPT

  SCHEMA = {
    type: "object", additionalProperties: false,
    required: %w[title summary points],
    properties: {
      title: { type: "string" },
      summary: { type: "string" },
      points: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[kind title quote],
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
    @feedback.update!(title: result["title"], summary: result["summary"],
                      extracted_points: { "points" => result["points"] })
  rescue LlmClient::Error => e
    Rails.logger.warn("[FeedbackAnalyzer] feedback=#{@feedback.id} failed: #{e.message}")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/feedback_analyzer_test.rb`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/services/feedback_analyzer.rb
git add app/services/feedback_analyzer.rb test/services/feedback_analyzer_test.rb
git commit -m "Add FeedbackAnalyzer for per-interview extraction"
```

---

### Task 5: `AnalyzeFeedbackJob` + enqueue from the webhook

**Files:**
- Create: `app/jobs/analyze_feedback_job.rb`
- Modify: `app/controllers/eleven_labs_webhooks_controller.rb` (enqueue in `create_feedback`)
- Test: `test/jobs/analyze_feedback_job_test.rb`, `test/controllers/eleven_labs_webhooks_controller_test.rb`

**Interfaces:**
- Consumes: `FeedbackAnalyzer#call` (Task 4).
- Produces: `AnalyzeFeedbackJob.perform_later(feedback)` runs Stage 1 for one feedback.

- [ ] **Step 1: Write the failing test**

`test/jobs/analyze_feedback_job_test.rb`:

```ruby
require "test_helper"

class AnalyzeFeedbackJobTest < ActiveJob::TestCase
  test "runs FeedbackAnalyzer for the feedback" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    called = nil
    stub_instance_method(FeedbackAnalyzer, :call, -> { called = true }) do
      AnalyzeFeedbackJob.perform_now(feedback)
    end
    assert called
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/analyze_feedback_job_test.rb`
Expected: FAIL — `uninitialized constant AnalyzeFeedbackJob`.

- [ ] **Step 3: Write the job**

`app/jobs/analyze_feedback_job.rb`:

```ruby
class AnalyzeFeedbackJob < ApplicationJob
  queue_as :default

  def perform(feedback)
    FeedbackAnalyzer.new(feedback).call
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/jobs/analyze_feedback_job_test.rb`
Expected: PASS.

- [ ] **Step 5: Enqueue from the webhook**

In `app/controllers/eleven_labs_webhooks_controller.rb`, in `create_feedback`, add the enqueue after the mailer line:

```ruby
  def create_feedback(loop_record)
    feedback = Feedback.create!(feedback_attributes.merge(loop: loop_record))
    LoopMailer.new_feedback(feedback).deliver_later
    AnalyzeFeedbackJob.perform_later(feedback)
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info("[ElevenLabs] already recorded conversation #{payload.conversation_id}")
  end
```

- [ ] **Step 6: Assert the enqueue in the webhook test**

Add to `test/controllers/eleven_labs_webhooks_controller_test.rb` (inside the existing valid-transcription test, or as a new test that posts a valid signed payload):

```ruby
  test "enqueues analysis for a newly recorded feedback" do
    assert_enqueued_with(job: AnalyzeFeedbackJob) do
      post_valid_transcription   # existing helper that signs and posts the fixture payload
    end
  end
```

If no such helper exists, mirror the existing valid-payload test's setup and wrap its `post` in `assert_enqueued_with`.

- [ ] **Step 7: Run tests and commit**

Run: `bin/rails test test/jobs/analyze_feedback_job_test.rb test/controllers/eleven_labs_webhooks_controller_test.rb`
Expected: PASS.

```bash
bin/rubocop app/jobs/analyze_feedback_job.rb app/controllers/eleven_labs_webhooks_controller.rb
git add app/jobs app/controllers/eleven_labs_webhooks_controller.rb test/jobs test/controllers/eleven_labs_webhooks_controller_test.rb
git commit -m "Enqueue per-feedback analysis on webhook ingestion"
```

---

### Task 6: `LoopAnalyzer` — Stage 2 clustering (LLM call)

**Files:**
- Create: `app/services/loop_analyzer.rb`
- Test: `test/services/loop_analyzer_test.rb`

**Interfaces:**
- Consumes: `LlmClient#complete` (Task 3), `Feedback#extracted_points`.
- Produces: `LoopAnalyzer.new(loop_record, client:).call -> Hash` — the clustered result (`overall_sentiment`, `summary`, `themes`, `feature_requests`), where each theme/request carries `citations: [{feedback_id, quote}]`. Persistence is Task 7. `LoopAnalyzer::SCHEMA` constant. `collect_points` tags every point with its `feedback_id`.

- [ ] **Step 1: Write the failing test**

`test/services/loop_analyzer_test.rb`:

```ruby
require "test_helper"

class LoopAnalyzerTest < ActiveSupport::TestCase
  CaptureStub = Struct.new(:payload) do
    attr_reader :user_arg
    def complete(system:, user:, schema:)
      @user_arg = user
      payload
    end
  end

  test "feeds tagged extracted points to the LLM and returns its result" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    fb = Feedback.create!(loop: loop_record, transcript: "hi",
                          extracted_points: { "points" => [{ "kind" => "theme", "title" => "Onboarding", "quote" => "too many features" }] })
    stub = CaptureStub.new({ "overall_sentiment" => "neutral", "summary" => "ok", "themes" => [], "feature_requests" => [] })

    result = LoopAnalyzer.new(loop_record, client: stub).call

    assert_equal "neutral", result["overall_sentiment"]
    assert_includes stub.user_arg, fb.id.to_s   # points were tagged with the feedback id
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/loop_analyzer_test.rb`
Expected: FAIL — `uninitialized constant LoopAnalyzer`.

- [ ] **Step 3: Write the service**

`app/services/loop_analyzer.rb`:

```ruby
class LoopAnalyzer
  SYSTEM = <<~PROMPT.freeze
    You cluster structured points extracted from many user interviews in one feedback loop.
    Input is a JSON list of points, each tagged with the `feedback_id` it came from.
    GROUP related points — do not re-summarize away the detail. Produce:
    - `overall_sentiment`: one of excited, positive, neutral, frustrated, negative.
    - `summary`: a narrative of where the product is going across all interviews.
    - `themes`: recurring patterns (include friction/pain points). Each has a title,
      one-line description, `mention_count` (how many interviews expressed it), a
      sentiment, and `citations` (feedback_id + the VERBATIM quote that supports it).
    - `feature_requests`: specific things users asked for, same citation shape.
    Every quote must be copied verbatim from the input points, never invented.
  PROMPT

  CITATIONS = {
    type: "array",
    items: {
      type: "object", additionalProperties: false, required: %w[feedback_id quote],
      properties: { feedback_id: { type: "integer" }, quote: { type: "string" } }
    }
  }.freeze

  SCHEMA = {
    type: "object", additionalProperties: false,
    required: %w[overall_sentiment summary themes feature_requests],
    properties: {
      overall_sentiment: { type: "string", enum: Feedback::SENTIMENT_VALUES },
      summary: { type: "string" },
      themes: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[title description mention_count sentiment citations],
          properties: {
            title: { type: "string" }, description: { type: "string" },
            mention_count: { type: "integer" },
            sentiment: { type: "string", enum: Feedback::SENTIMENT_VALUES },
            citations: CITATIONS
          }
        }
      },
      feature_requests: {
        type: "array",
        items: {
          type: "object", additionalProperties: false,
          required: %w[title description citations],
          properties: { title: { type: "string" }, description: { type: "string" }, citations: CITATIONS }
        }
      }
    }
  }.freeze

  def initialize(loop_record, client: LlmClient.new)
    @loop = loop_record
    @client = client
  end

  def call
    @client.complete(system: SYSTEM, user: collect_points.to_json, schema: SCHEMA)
  end

  def analyzed_count
    @loop.feedbacks.where.not(extracted_points: {}).count
  end

  private

  def collect_points
    @loop.feedbacks.where.not(extracted_points: {}).flat_map do |feedback|
      Array(feedback.extracted_points["points"]).map { |point| point.merge("feedback_id" => feedback.id) }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/loop_analyzer_test.rb`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
bin/rubocop app/services/loop_analyzer.rb
git add app/services/loop_analyzer.rb test/services/loop_analyzer_test.rb
git commit -m "Add LoopAnalyzer clustering call for loop-level analysis"
```

---

### Task 7: `LoopInsightWriter` + `AnalyzeLoopJob` — persist the analysis graph

**Files:**
- Create: `app/services/loop_insight_writer.rb`
- Create: `app/jobs/analyze_loop_job.rb`
- Create: `lib/tasks/analysis.rake` (backfill)
- Test: `test/services/loop_insight_writer_test.rb`, `test/jobs/analyze_loop_job_test.rb`

**Interfaces:**
- Consumes: `LoopAnalyzer#call` result + `#analyzed_count` (Task 6).
- Produces: `LoopInsightWriter.new(loop_record, result, analyzed_count).call` — atomically replaces the loop's `Insight` + `Theme`/`FeatureRequest`/`Quote` graph. `AnalyzeLoopJob.perform_later(loop_record)` runs Stage 2 end-to-end. Rake task `analysis:backfill` enqueues Stage 1 for feedback missing extractions.

Split from `LoopAnalyzer` to keep each class under the 100-line rubocop cap: the analyzer talks to the LLM, the writer talks to the database.

- [ ] **Step 1: Write the failing test**

`test/services/loop_insight_writer_test.rb`:

```ruby
require "test_helper"

class LoopInsightWriterTest < ActiveSupport::TestCase
  test "rebuilds the insight graph with themes, requests, and quotes" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    feedback = Feedback.create!(loop: loop_record, transcript: "hi")
    result = {
      "overall_sentiment" => "positive", "summary" => "Going well",
      "themes" => [{ "title" => "Onboarding", "description" => "hard start", "mention_count" => 1,
                     "sentiment" => "frustrated", "citations" => [{ "feedback_id" => feedback.id, "quote" => "too many features" }] }],
      "feature_requests" => [{ "title" => "Walkthrough", "description" => "guided", "citations" => [] }]
    }

    LoopInsightWriter.new(loop_record, result, 1).call

    insight = loop_record.reload.insight
    assert_equal "positive", insight.overall_sentiment
    assert_equal 1, insight.analyzed_feedback_count
    theme = insight.themes.first
    assert_equal "Onboarding", theme.title
    assert_equal "too many features", theme.quotes.first.text
    assert_equal feedback, theme.quotes.first.feedback
  end

  test "replaces a prior analysis rather than appending" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    empty = { "overall_sentiment" => "neutral", "summary" => "", "themes" => [], "feature_requests" => [] }
    LoopInsightWriter.new(loop_record, empty.merge("summary" => "first"), 0).call
    LoopInsightWriter.new(loop_record, empty.merge("summary" => "second"), 0).call
    assert_equal 1, loop_record.reload.insight.persisted? ? Insight.where(loop: loop_record).count : 0
    assert_equal "second", loop_record.insight.summary
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/loop_insight_writer_test.rb`
Expected: FAIL — `uninitialized constant LoopInsightWriter`.

- [ ] **Step 3: Write the writer**

`app/services/loop_insight_writer.rb`:

```ruby
class LoopInsightWriter
  def initialize(loop_record, result, analyzed_count)
    @loop = loop_record
    @result = result
    @analyzed_count = analyzed_count
  end

  def call
    ActiveRecord::Base.transaction do
      @loop.insight&.destroy!
      insight = build_insight
      Array(@result["themes"]).each { |data| build_theme(insight, data) }
      Array(@result["feature_requests"]).each { |data| build_request(insight, data) }
    end
  end

  private

  def build_insight
    @loop.create_insight!(
      summary: @result["summary"], overall_sentiment: @result["overall_sentiment"],
      analyzed_feedback_count: @analyzed_count, generated_at: Time.current
    )
  end

  def build_theme(insight, data)
    theme = insight.themes.create!(data.slice("title", "description", "mention_count", "sentiment"))
    build_quotes(theme, data["citations"])
  end

  def build_request(insight, data)
    request = insight.feature_requests.create!(data.slice("title", "description"))
    build_quotes(request, data["citations"])
  end

  def build_quotes(quotable, citations)
    feedback_ids = quotable.insight.loop.feedbacks.pluck(:id).to_set
    Array(citations).each do |citation|
      next unless feedback_ids.include?(citation["feedback_id"])

      quotable.quotes.create!(feedback_id: citation["feedback_id"], text: citation["quote"])
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/loop_insight_writer_test.rb`
Expected: PASS.

- [ ] **Step 5: Write the job and its test**

`app/jobs/analyze_loop_job.rb`:

```ruby
class AnalyzeLoopJob < ApplicationJob
  queue_as :default

  def perform(loop_record)
    analyzer = LoopAnalyzer.new(loop_record)
    LoopInsightWriter.new(loop_record, analyzer.call, analyzer.analyzed_count).call
  end
end
```

`test/jobs/analyze_loop_job_test.rb`:

```ruby
require "test_helper"

class AnalyzeLoopJobTest < ActiveJob::TestCase
  test "analyzes then writes the insight" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    Feedback.create!(loop: loop_record, transcript: "hi",
                     extracted_points: { "points" => [{ "kind" => "theme", "title" => "T", "quote" => "q" }] })
    result = { "overall_sentiment" => "neutral", "summary" => "s", "themes" => [], "feature_requests" => [] }

    stub_instance_method(LoopAnalyzer, :call, -> { result }) do
      AnalyzeLoopJob.perform_now(loop_record)
    end

    assert_equal "s", loop_record.reload.insight.summary
  end
end
```

- [ ] **Step 6: Write the backfill rake task**

`lib/tasks/analysis.rake`:

```ruby
namespace :analysis do
  desc "Enqueue Stage 1 extraction for feedback that has none yet"
  task backfill: :environment do
    Feedback.where(extracted_points: {}).find_each do |feedback|
      AnalyzeFeedbackJob.perform_later(feedback)
    end
  end
end
```

- [ ] **Step 7: Run tests and commit**

Run: `bin/rails test test/services/loop_insight_writer_test.rb test/jobs/analyze_loop_job_test.rb`
Expected: PASS.

```bash
bin/rubocop app/services/loop_insight_writer.rb app/jobs/analyze_loop_job.rb
git add app/services/loop_insight_writer.rb app/jobs/analyze_loop_job.rb lib/tasks/analysis.rake test/services/loop_insight_writer_test.rb test/jobs/analyze_loop_job_test.rb
git commit -m "Persist loop analysis graph and add backfill task"
```

---

### Task 8: On-demand refresh action + staleness helper

**Files:**
- Modify: `config/routes.rb` (add refresh route)
- Modify: `app/controllers/analyse_controller.rb` (add `refresh`)
- Modify: `app/models/loop.rb` (add `unanalyzed_feedback_count`)
- Test: `test/models/loop_test.rb`, `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `AnalyzeLoopJob.perform_later` (Task 7).
- Produces: `POST /analyse/:slug/refresh` (`refresh_analyse_path`) enqueues the loop analysis. `Loop#unanalyzed_feedback_count -> Integer` (new interviews since last analysis).

- [ ] **Step 1: Write the failing model test**

Add to `test/models/loop_test.rb`:

```ruby
  test "unanalyzed_feedback_count counts interviews since the last analysis" do
    loop_record = Loop.create!(name: "L", user: users(:founder))
    3.times { Feedback.create!(loop: loop_record, transcript: "hi") }
    loop_record.create_insight!(analyzed_feedback_count: 1)
    assert_equal 2, loop_record.unanalyzed_feedback_count
  end
```

- [ ] **Step 2: Run it to confirm failure**

Run: `bin/rails test test/models/loop_test.rb`
Expected: FAIL — `undefined method 'unanalyzed_feedback_count'`.

- [ ] **Step 3: Implement the helper**

Add to `app/models/loop.rb`:

```ruby
  def unanalyzed_feedback_count
    feedbacks.count - (insight&.analyzed_feedback_count || 0)
  end
```

- [ ] **Step 4: Add the route**

In `config/routes.rb`, beside the existing analyse routes:

```ruby
  post "analyse/:slug/refresh", to: "analyse#refresh", as: :refresh_analyse
```

- [ ] **Step 5: Add the controller action**

In `app/controllers/analyse_controller.rb`:

```ruby
  def refresh
    loop_record = current_workspace_owner.loops.find_by!(slug: params[:slug])
    AnalyzeLoopJob.perform_later(loop_record)
    redirect_to analyse_path(loop_record.slug), notice: "Analysis started — this can take a moment."
  end
```

- [ ] **Step 6: Write the controller test**

Add to `test/controllers/analyse_controller_test.rb` (sign in as the founder as the other tests do):

```ruby
  test "refresh enqueues the loop analysis" do
    sign_in users(:founder)
    loop_record = Loop.create!(name: "L", user: users(:founder))
    assert_enqueued_with(job: AnalyzeLoopJob) do
      post refresh_analyse_path(loop_record.slug)
    end
    assert_redirected_to analyse_path(loop_record.slug)
  end
```

- [ ] **Step 7: Run tests and commit**

Run: `bin/rails test test/models/loop_test.rb test/controllers/analyse_controller_test.rb`
Expected: PASS.

```bash
bin/rubocop app/models/loop.rb app/controllers/analyse_controller.rb
git add config/routes.rb app/controllers/analyse_controller.rb app/models/loop.rb test/models/loop_test.rb test/controllers/analyse_controller_test.rb
git commit -m "Add on-demand analysis refresh and staleness helper"
```

---

### Task 9: Reshape the Analyse tab UI

**Files:**
- Modify: `app/views/analyse/show.html.erb` (Insight panel, Themes, Requests, feedback cards)
- Create: `app/views/analyse/_insight_panel.html.erb`, `_theme.html.erb`, `_feature_request.html.erb`
- Test: `test/controllers/analyse_controller_test.rb` (render assertions)

**Interfaces:**
- Consumes: `@loop.insight`, `insight.themes`, `insight.feature_requests`, `Loop#unanalyzed_feedback_count` (Task 8), `sentiment_badge` helper (existing).

- [ ] **Step 1: Write the failing render test**

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "shows the insight panel and themes when an analysis exists" do
    sign_in users(:founder)
    loop_record = Loop.create!(name: "L", user: users(:founder))
    insight = loop_record.create_insight!(summary: "Going well", overall_sentiment: "positive", analyzed_feedback_count: 1)
    insight.themes.create!(title: "Onboarding overwhelming", mention_count: 3, sentiment: "frustrated")

    get analyse_path(loop_record.slug)

    assert_select ".analysis-summary-card", text: /Going well/
    assert_select ".theme-card", text: /Onboarding overwhelming/
  end
```

- [ ] **Step 2: Run it to confirm failure**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: FAIL — the panel still says "Summary coming soon"; no `.theme-card`.

- [ ] **Step 3: Replace the "Summary coming soon" card**

In `app/views/analyse/show.html.erb`, replace the placeholder card (the `col-md-4` div containing `analysis-summary-card` / "Summary coming soon") with:

```erb
<div class="col-md-4">
  <%= render "insight_panel", loop_record: @loop %>
</div>
```

- [ ] **Step 4: Write the insight panel partial**

`app/views/analyse/_insight_panel.html.erb`:

```erb
<div class="analysis-summary-card h-100 p-3">
  <div class="d-flex justify-content-between align-items-start mb-2">
    <h3 class="h6 text-uppercase text-muted mb-0">Insight</h3>
    <%= button_to "Refresh analysis", refresh_analyse_path(loop_record.slug),
                  class: "btn btn-sm btn-outline-primary" %>
  </div>

  <% if loop_record.insight.present? %>
    <div class="mb-2"><%= sentiment_badge(loop_record.insight.overall_sentiment) %></div>
    <p class="mb-2"><%= loop_record.insight.summary %></p>
    <p class="text-muted small mb-0">
      <%= pluralize(loop_record.insight.analyzed_feedback_count, "interview") %> analyzed
      <% if loop_record.unanalyzed_feedback_count.positive? %>
        · <%= pluralize(loop_record.unanalyzed_feedback_count, "new response") %> since
      <% end %>
    </p>
  <% else %>
    <p class="text-muted mb-0">No analysis yet. Press <strong>Refresh analysis</strong> to generate insights.</p>
  <% end %>
</div>
```

- [ ] **Step 5: Add Themes and Requests sections**

In `app/views/analyse/show.html.erb`, immediately after the `row g-4 mb-4` block that holds the chart + insight panel, add:

```erb
<% if @loop.insight.present? %>
  <% if @loop.insight.themes.any? %>
    <h3 class="mb-3">Themes</h3>
    <div class="d-flex flex-column gap-2 mb-4">
      <%= render partial: "theme", collection: @loop.insight.themes, as: :theme %>
    </div>
  <% end %>

  <% if @loop.insight.feature_requests.any? %>
    <h3 class="mb-3">Feature requests</h3>
    <div class="d-flex flex-column gap-2 mb-4">
      <%= render partial: "feature_request", collection: @loop.insight.feature_requests, as: :feature_request %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 6: Write the theme and request partials**

`app/views/analyse/_theme.html.erb`:

```erb
<div class="theme-card border rounded p-3">
  <div class="d-flex justify-content-between align-items-start gap-2 mb-1">
    <span class="fw-semibold"><%= theme.title %></span>
    <div class="d-flex align-items-center gap-2">
      <%= sentiment_badge(theme.sentiment) %>
      <span class="badge text-bg-light"><%= pluralize(theme.mention_count, "interview") %></span>
    </div>
  </div>
  <p class="text-muted small mb-2"><%= theme.description %></p>
  <% theme.quotes.each do |quote| %>
    <blockquote class="border-start ps-2 mb-1 small fst-italic text-muted">
      "<%= quote.text %>"
    </blockquote>
  <% end %>
</div>
```

`app/views/analyse/_feature_request.html.erb`:

```erb
<div class="feature-request-card border rounded p-3">
  <div class="fw-semibold mb-1"><%= feature_request.title %></div>
  <p class="text-muted small mb-2"><%= feature_request.description %></p>
  <% feature_request.quotes.each do |quote| %>
    <blockquote class="border-start ps-2 mb-1 small fst-italic text-muted">"<%= quote.text %>"</blockquote>
  <% end %>
</div>
```

- [ ] **Step 7: Lead the feedback cards with the summary**

In `app/views/analyse/show.html.erb`, in the per-feedback card loop, insert the title/summary above the transcript and wrap the transcript in a collapsible `<details>`:

```erb
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
```

(Replace the existing single `<p class="analysis-transcript ...">` line with this conditional.)

- [ ] **Step 8: Run the render test and commit**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: PASS.

```bash
bin/rubocop
git add app/views/analyse test/controllers/analyse_controller_test.rb
git commit -m "Reshape Analyse tab with insight panel, themes, and requests"
```

---

### Task 10: Wire the notification bell (staleness prompt)

**Files:**
- Modify: `app/controllers/application_controller.rb` (expose an unanalyzed-count helper)
- Modify: `app/views/shared/_navbar.html.erb` (badge + dropdown)
- Test: `test/controllers/dashboard_controller_test.rb` (or any authenticated controller test) for the helper

**Interfaces:**
- Consumes: `Loop#unanalyzed_feedback_count` (Task 8), `current_workspace_owner` (existing).
- Produces: `unanalyzed_feedback_total` + `loops_with_new_feedback` helper methods for the navbar.

This is the discoverability layer on top of the load-bearing Refresh button; if it grows, it can ship separately.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/dashboard_controller_test.rb`:

```ruby
  test "navbar bell shows the count of new responses across loops" do
    sign_in users(:founder)
    loop_record = Loop.create!(name: "L", user: users(:founder))
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }
    loop_record.create_insight!(analyzed_feedback_count: 0)

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "2"
  end
```

- [ ] **Step 2: Run it to confirm failure**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb`
Expected: FAIL — no `.app-alert-badge`.

- [ ] **Step 3: Add the helpers**

In `app/controllers/application_controller.rb`, extend the `helper_method` list and add the methods:

```ruby
  helper_method :current_workspace_owner, :current_user_workspace_admin?,
                :unanalyzed_feedback_total, :loops_with_new_feedback

  def loops_with_new_feedback
    current_workspace_owner.loops.includes(:insight, :feedbacks).select { |loop| loop.unanalyzed_feedback_count.positive? }
  end

  def unanalyzed_feedback_total
    loops_with_new_feedback.sum(&:unanalyzed_feedback_count)
  end
```

Place `loops_with_new_feedback` / `unanalyzed_feedback_total` under `private` alongside the existing helpers.

- [ ] **Step 4: Render the badge and dropdown in the navbar**

Replace the static bell button in `app/views/shared/_navbar.html.erb` with:

```erb
<div class="dropdown">
  <button type="button" class="btn app-alert-button position-relative" data-bs-toggle="dropdown"
          aria-label="Notifications" aria-expanded="false">
    <i class="fa-regular fa-bell" aria-hidden="true"></i>
    <% if unanalyzed_feedback_total.positive? %>
      <span class="app-alert-badge badge rounded-pill text-bg-danger"><%= unanalyzed_feedback_total %></span>
    <% end %>
  </button>
  <ul class="dropdown-menu dropdown-menu-end">
    <% if loops_with_new_feedback.any? %>
      <% loops_with_new_feedback.each do |loop_record| %>
        <li>
          <%= link_to analyse_path(loop_record.slug), class: "dropdown-item" do %>
            <strong><%= loop_record.name %></strong> —
            <%= pluralize(loop_record.unanalyzed_feedback_count, "new response") %>
          <% end %>
        </li>
      <% end %>
    <% else %>
      <li><span class="dropdown-item-text text-muted">No new responses</span></li>
    <% end %>
  </ul>
</div>
```

- [ ] **Step 5: Run the test and commit**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb`
Expected: PASS.

```bash
bin/rubocop app/controllers/application_controller.rb
git add app/controllers/application_controller.rb app/views/shared/_navbar.html.erb test/controllers/dashboard_controller_test.rb
git commit -m "Wire notification bell to unanalyzed feedback count"
```

---

### Task 11: Configuration, infrastructure, and full CI

**Files:**
- Modify: `.env` (local `OPENAI_API_KEY`)
- Verify: `config/puma.rb` (Solid Queue supervisor)
- Docs/ops only — no test

**Interfaces:** none (deployment wiring).

- [ ] **Step 1: Local API key**

Add to `.env` (not committed): `OPENAI_API_KEY=sk-...`. Confirm `dotenv-rails` loads it: `bin/rails runner 'puts ENV.fetch("OPENAI_API_KEY").present?'` → `true`.

- [ ] **Step 2: Ensure jobs actually run**

This feature adds the app's first real background jobs. Production has no worker dyno, so the Solid Queue supervisor must run inside the web dyno. Set the Heroku config vars:

```bash
heroku config:set OPENAI_API_KEY=sk-... SOLID_QUEUE_IN_PUMA=1 --app loop-ai
```

Confirm `config/puma.rb` starts the supervisor when `SOLID_QUEUE_IN_PUMA` is set (existing line around `config/puma.rb:38`). Locally, run jobs inline or via `bin/jobs` when testing the end-to-end flow.

- [ ] **Step 3: Run the full CI pipeline**

Run: `bin/ci`
Expected: green except the pre-existing `PagesControllerTest#test_signed-in_visitors_can_view_the_landing_page` (stale baseline, not ours). If anything *else* is red, fix it before finishing.

- [ ] **Step 4: Manual end-to-end smoke (optional but recommended)**

With `OPENAI_API_KEY` set and jobs running: seed a loop with a few feedbacks (`bin/rails db:seed:replant`), run `bin/rails analysis:backfill`, open `/analyse/:slug`, press **Refresh analysis**, and confirm the insight panel, themes, and requests populate with real quotes.

- [ ] **Step 5: Commit any config changes**

```bash
git add config/puma.rb
git commit -m "Document Solid Queue + OpenAI config for feedback analysis" --allow-empty
```

---

## Self-Review

**Spec coverage:**
- Two-grain data model → Tasks 1–2. ✓
- Extract-then-cluster pipeline (verbatim-quote fidelity) → Tasks 4 (extract), 6 (cluster), 7 (persist); fidelity guarded by the verbatim `quote` schema fields and the LoopInsightWriter quote test. ✓
- GPT-5 mini behind a swappable seam → Task 3. ✓
- On-demand generation + staleness → Task 8; bell → Task 10. ✓
- UI reshape into the existing Analyse tab (insight panel, themes, requests, collapsible transcript, in-progress/empty states) → Task 9. ✓
- Backfill of existing feedback → Task 7 rake task. ✓
- Partial-failure degradation → Task 4 graceful rescue. ✓
- Infra (Solid Queue worker, keys) → Task 11. ✓
- Privacy (PII to OpenAI) → Global Constraints + only transcript text sent (Task 4/6 send `transcript`/points, never identity). The business/legal sub-processor decision is called out in the spec and is outside code scope.

**Deviation from spec, noted:** the spec's Stage-1 fallback mentioned reusing ElevenLabs' `transcript_summary`/`call_summary_title`; those are not currently persisted, so Task 4 degrades to nil title/summary (card falls back to transcript + sentiment) rather than adding webhook-payload capture. Same user-facing outcome (nothing breaks); capturing ElevenLabs' free summary as an instant baseline remains an easy future enhancement.

**Type consistency:** `LlmClient#complete(system:, user:, schema:)` is called identically in Tasks 4 and 6. `LoopAnalyzer#call` returns the hash consumed by `LoopInsightWriter` (Task 7) and `AnalyzeLoopJob`. `Loop#unanalyzed_feedback_count` defined in Task 8, consumed in Tasks 9–10. `Feedback::SENTIMENT_VALUES` reused for every sentiment enum. Consistent.

**Placeholder scan:** no TBD/TODO; every code step carries complete code.
