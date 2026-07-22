# Notification Bell "Seen" State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a loop's entry in the navbar notification bell disappear on its own once a user visits that loop's analyse page — no dismiss button, per-user, independent of Stage 2 analysis staleness.

**Architecture:** A new `loop_views` join table records, per `(user, loop)`, the feedback count the user last saw. `AnalyseController` stamps it on every visit to a loop's analyse page. `ApplicationController`'s bell helpers switch from comparing against `insight.analyzed_feedback_count` to comparing against this per-user stamp.

**Tech Stack:** Rails 8.1, PostgreSQL, Minitest (`ActionDispatch::IntegrationTest`, `ActiveSupport::TestCase`), Devise test helpers.

## Global Constraints

- Ruby 3.3.9 / Rails 8.1 / PostgreSQL, migrations use `ActiveRecord::Migration[8.1]`.
- `Metrics/MethodLength` (max 10 lines) and `Metrics/ClassLength` (max 100 lines) are enforced by `.rubocop.yml` — keep methods short.
- No fixtures are used in this codebase's tests; test data is built inline with `User.create!` / `@user.loops.create!` / etc.
- Every loop is scoped through `current_organization` (== `current_user.organization`), never `current_user` directly, for anything workspace-shared — but seen-state here is deliberately per-`current_user`, not per-organization.
- Run `bin/rubocop` and the relevant `bin/rails test` files before each commit; run `bin/ci` once at the end.

---

### Task 1: `loop_views` table and `LoopView` model

**Files:**
- Create: `db/migrate/20260722090000_create_loop_views.rb`
- Modify: `db/schema.rb` (via `bin/rails db:migrate`, not hand-edited)
- Create: `app/models/loop_view.rb`
- Modify: `app/models/user.rb` (add `has_many :loop_views`)
- Modify: `app/models/loop.rb` (add `has_many :loop_views`)
- Test: `test/models/loop_view_test.rb`

**Interfaces:**
- Produces: `LoopView` model with `belongs_to :user`, `belongs_to :loop`, integer column `last_seen_feedback_count` (default `0`). Unique on `[user_id, loop_id]`. `User#loop_views`, `Loop#loop_views` associations.

- [ ] **Step 1: Write the failing model test**

```ruby
require "test_helper"

class LoopViewTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "founder@example.com", password: "password123")
    @loop = @user.loops.create!(name: "L")
  end

  test "defaults last_seen_feedback_count to 0" do
    loop_view = LoopView.create!(user: @user, loop: @loop)

    assert_equal 0, loop_view.last_seen_feedback_count
  end

  test "enforces one row per user and loop" do
    LoopView.create!(user: @user, loop: @loop, last_seen_feedback_count: 1)
    duplicate = LoopView.new(user: @user, loop: @loop, last_seen_feedback_count: 2)

    assert_not duplicate.valid?
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/loop_view_test.rb`
Expected: FAIL — `uninitialized constant LoopView` (no model or table yet).

- [ ] **Step 3: Write the migration**

```ruby
class CreateLoopViews < ActiveRecord::Migration[8.1]
  def change
    create_table :loop_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :loop, null: false, foreign_key: true
      t.integer :last_seen_feedback_count, null: false, default: 0

      t.timestamps
    end

    add_index :loop_views, %i[user_id loop_id], unique: true
  end
end
```

Run: `bin/rails db:migrate`
Expected: migration runs, `db/schema.rb` gains a `loop_views` table with a unique index on `["user_id", "loop_id"]`.

- [ ] **Step 4: Write the model and associations**

`app/models/loop_view.rb`:

```ruby
class LoopView < ApplicationRecord
  belongs_to :user
  belongs_to :loop

  validates :user_id, uniqueness: { scope: :loop_id }
end
```

In `app/models/user.rb`, add alongside the other `has_many` lines:

```ruby
  has_many :loop_views, dependent: :destroy
```

In `app/models/loop.rb`, add alongside `has_many :feedbacks`:

```ruby
  has_many :loop_views, dependent: :destroy
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/loop_view_test.rb`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 6: Rubocop and commit**

Run: `bin/rubocop app/models/loop_view.rb app/models/user.rb app/models/loop.rb`
Expected: no offenses.

```bash
git add db/migrate/20260722090000_create_loop_views.rb db/schema.rb app/models/loop_view.rb app/models/user.rb app/models/loop.rb test/models/loop_view_test.rb
git commit -m "Add LoopView model to record per-user last-seen feedback count"
```

---

### Task 2: Stamp "seen" when a user visits a loop's analyse page

**Files:**
- Modify: `app/controllers/analyse_controller.rb`
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `LoopView` (Task 1) — `current_user.loop_views.find_or_initialize_by(loop:)`, `#last_seen_feedback_count`.
- Produces: after any `GET` to `analyse_path(loop.slug)` or `analyse_index_path` (which renders the same view for the most recent loop), `current_user.loop_views.find_by(loop: @loop).last_seen_feedback_count == @loop.feedbacks.size`.

- [ ] **Step 1: Write the failing integration test**

Add to `test/controllers/analyse_controller_test.rb` (inside the class, near the other tests):

```ruby
  test "visiting a loop's analyse page stamps the current user's last-seen feedback count" do
    loop_record = @user.loops.create!(name: "L")
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }

    get analyse_path(loop_record.slug)

    loop_view = @user.loop_views.find_by(loop: loop_record)
    assert_equal 2, loop_view.last_seen_feedback_count
  end

  test "visiting a loop with no feedback yet does not create a loop_view row" do
    loop_record = @user.loops.create!(name: "L")

    get analyse_path(loop_record.slug)

    assert_nil @user.loop_views.find_by(loop: loop_record)
  end

  test "visiting a loop again without new feedback does not regress last_seen_feedback_count" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyse_path(loop_record.slug)
    loop_view = @user.loop_views.find_by(loop: loop_record)
    loop_view.update!(last_seen_feedback_count: 5)

    get analyse_path(loop_record.slug)

    assert_equal 5, loop_view.reload.last_seen_feedback_count
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyse_controller_test.rb -n "/stamps the current user|does not create a loop_view|does not regress/"`
Expected: first test FAILs (`loop_view` is `nil`, `NoMethodError` on `last_seen_feedback_count`); other two currently pass vacuously — check after Step 1 they still describe real behavior once Step 3 lands (they'll fail if the guard/no-regression logic is missing).

- [ ] **Step 3: Add the stamping logic**

In `app/controllers/analyse_controller.rb`, update `load_shared_data` and add a private method:

```ruby
  def load_shared_data
    mark_loop_seen!(@loop) if @loop

    @active_tab = params[:tab].presence_in(TABS) || "per_loop"
    @range = params[:range].presence_in(RANGES) || "30d"
    @from, @to = range_bounds(@range)

    load_per_loop_data
    load_all_loops_data
  end
```

```ruby
  def mark_loop_seen!(loop_record)
    loop_view = current_user.loop_views.find_or_initialize_by(loop: loop_record)
    count = loop_record.feedbacks.size
    loop_view.update!(last_seen_feedback_count: count) if count > loop_view.last_seen_feedback_count.to_i
  end
```

Place `mark_loop_seen!` in the existing `private` section, near the top (it's called first).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyse_controller_test.rb`
Expected: PASS, all tests in the file (including the pre-existing ones) green.

- [ ] **Step 5: Rubocop and commit**

Run: `bin/rubocop app/controllers/analyse_controller.rb`
Expected: no offenses.

```bash
git add app/controllers/analyse_controller.rb test/controllers/analyse_controller_test.rb
git commit -m "Stamp per-user last-seen feedback count when visiting a loop's analyse page"
```

---

### Task 3: Bell badge and dropdown use per-user seen state

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/views/shared/_navbar.html.erb`
- Test: `test/controllers/dashboard_controller_test.rb`
- Test: `test/controllers/analyse_controller_test.rb`

**Interfaces:**
- Consumes: `LoopView` (Task 1), the seen-stamping behavior of `AnalyseController#show`/`#index` (Task 2).
- Produces: `new_feedback_count_for(loop_record)` (helper method, returns a non-negative `Integer`), `new_feedback_total` (helper method, replaces `unanalyzed_feedback_total`), `loops_with_new_feedback` (unchanged name/shape — an array of `Loop`s).

- [ ] **Step 1: Write the failing tests**

Add to `test/controllers/dashboard_controller_test.rb` (replace the existing single test with these three — the first is the original test, still valid since no `LoopView` row exists yet):

```ruby
  test "navbar bell shows the count of new responses across loops" do
    loop_record = @user.loops.create!(name: "L")
    2.times { Feedback.create!(loop: loop_record, transcript: "hi") }

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "2"
  end

  test "navbar bell drops to zero once the current user has viewed the loop" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyse_path(loop_record.slug)

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", count: 0
  end

  test "navbar bell only counts feedback that arrived after the user last viewed the loop" do
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "first")
    get analyse_path(loop_record.slug)
    Feedback.create!(loop: loop_record, transcript: "second")

    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "1"
  end
```

Add to `test/controllers/analyse_controller_test.rb`:

```ruby
  test "one teammate viewing a loop does not clear the notification for another teammate" do
    teammate = User.create!(email: "teammate@example.com", password: "password123")
    @user.team_memberships.create!(email: teammate.email, role: :editor, user: teammate,
                                   invitation_accepted_at: Time.current)
    loop_record = @user.loops.create!(name: "L")
    Feedback.create!(loop: loop_record, transcript: "hi")
    get analyse_path(loop_record.slug)

    sign_out @user
    sign_in teammate
    get dashboard_path

    assert_select ".app-alert-button .app-alert-badge", text: "1"
  end
```

(This last test needs `dashboard_path` — `AnalyseControllerTest` doesn't route there today, but the route exists app-wide via `Devise::Test::IntegrationHelpers`, already included.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb test/controllers/analyse_controller_test.rb -n "/navbar bell|does not clear the notification/"`
Expected: the two new "drops to zero" / "only counts feedback that arrived after" / "does not clear" tests FAIL (badge still shows the old `unanalyzed_feedback_count`-based number, unaffected by the visit).

- [ ] **Step 3: Update `ApplicationController`**

Replace the `helper_method` line, `loops_with_new_feedback`, and `unanalyzed_feedback_total` in `app/controllers/application_controller.rb`:

```ruby
  helper_method :current_organization, :current_user_workspace_admin?,
                :new_feedback_total, :loops_with_new_feedback, :new_feedback_count_for
```

```ruby
  def loops_with_new_feedback
    loops = current_organization.loops.includes(:feedbacks)
    loops.select { |loop_record| new_feedback_count_for(loop_record).positive? }
  end

  def new_feedback_count_for(loop_record)
    seen = loop_seen_counts[loop_record.id].to_i
    [loop_record.feedbacks.size - seen, 0].max
  end

  def new_feedback_total
    loops_with_new_feedback.sum { |loop_record| new_feedback_count_for(loop_record) }
  end
```

Add to the `private` section:

```ruby
  def loop_seen_counts
    @loop_seen_counts ||= current_user.loop_views.pluck(:loop_id, :last_seen_feedback_count).to_h
  end
```

- [ ] **Step 4: Update the navbar view**

In `app/views/shared/_navbar.html.erb`, change:

```erb
          <% if unanalyzed_feedback_total.positive? %>
            <span class="app-alert-badge badge rounded-pill text-bg-danger"><%= unanalyzed_feedback_total %></span>
          <% end %>
```

to:

```erb
          <% if new_feedback_total.positive? %>
            <span class="app-alert-badge badge rounded-pill text-bg-danger"><%= new_feedback_total %></span>
          <% end %>
```

and change:

```erb
                  <%= pluralize(loop_record.unanalyzed_feedback_count, "new response") %>
```

to:

```erb
                  <%= pluralize(new_feedback_count_for(loop_record), "new response") %>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/dashboard_controller_test.rb test/controllers/analyse_controller_test.rb`
Expected: PASS, every test in both files green.

- [ ] **Step 6: Full suite, rubocop, commit**

Run: `bin/rails test`
Expected: same pass/fail state as before this plan started (the pre-existing `PagesControllerTest` redirect failure on `master` is not this work's concern — confirm no *new* failures).

Run: `bin/rubocop app/controllers/application_controller.rb app/views/shared/_navbar.html.erb`
Expected: no offenses (note: `.erb` files aren't Ruby-linted by rubocop; this call only lints the controller — running it is still worth doing for that file).

```bash
git add app/controllers/application_controller.rb app/views/shared/_navbar.html.erb test/controllers/dashboard_controller_test.rb test/controllers/analyse_controller_test.rb
git commit -m "Base bell badge and dropdown on per-user last-seen state, not analysis staleness"
```

- [ ] **Step 7: Run `bin/ci`**

Run: `bin/ci`
Expected: same result as the documented baseline (red only on the pre-existing `PagesControllerTest` failure noted in `CLAUDE.md` — nothing new).

---

## Post-plan check

`Loop#unanalyzed_feedback_count` and the Insight panel's "N new responses since — Refresh to include them" note (`app/views/analyse/_insight_panel.html.erb`) are untouched by this plan — confirm with `git diff` before merging that neither file appears in the diff.
