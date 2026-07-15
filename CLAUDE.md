# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**loop-ai** — a Rails 8.1 app for collecting and analyzing feedback via "loops". A `User` owns `Loop`s; each loop has ordered `Question`s, collects `Feedback` (respondent transcripts), and produces an `Insight` (sentiment + summary). The AI angle — provisioning a voice agent per loop, letting respondents talk to it, then turning raw feedback transcripts into insights — is the focus of active work. Agent provisioning and the public respondent voice flow are now wired end-to-end; turning the resulting transcripts into `Feedback` and `Insight`s is the next frontier.

Working parts today: `LoopsController` is a full CRUD (`index`/`new`/`create`/`edit`/`update`/`destroy`) plus `activate`/`deactivate` member actions (provision the ElevenLabs agent + flip `status`); `RespondentsController` (`show` + `signed_url`) is the public voice-interview flow (see below); `AnalyseController` (`index` + `show`) renders a feedback-review dashboard, selecting a loop by `slug`. The `Questions`, `Feedbacks`, and `Insights` controllers are still empty class bodies with no routes — build them out as needed. A `loops.agent_id` (string) column holds the ElevenLabs agent ID and is set on activation (see below); it's the anchor for the feedback-to-insight work. API keys come via `.env` (`dotenv-rails` present); `ELEVENLABS_API_KEY` is expected there.

**AI / agent work**: the loop-respondent side targets ElevenLabs conversational agents, wired end-to-end for *provisioning* and the *respondent voice flow*:
- `app/services/system_prompt_builder.rb` (`SystemPromptBuilder.new(loop).call`) turns a `Loop`'s `description` (Goal) and `Question`s ordered by `position` (numbered list) into an ElevenLabs system-prompt string plus a fixed Rules block. String-only, no HTTP.
- `app/services/eleven_labs_agent_creator.rb` (`ElevenLabsAgentCreator.new(loop).call`) POSTs to the ElevenLabs `convai/agents/create` API (via the `rest-client` gem) using that prompt, and returns the new `agent_id`. It has a request timeout and wraps every failure (HTTP error, timeout, unreachable host, missing key, missing `agent_id`) in a single `ElevenLabsAgentCreator::Error` with a readable message.
- `LoopsController#activate` (`POST /loops/:id/activate`) is the trigger. Design decisions baked in: **provision on activation only** (not on create/edit — no surprise API calls), **create-once** (guarded — skips the call if the loop is already `active` or already has an `agent_id`, so no duplicate agents), and **synchronous** (calls inline and flashes success/error immediately rather than a background job). On success it sets `agent_id` + `status: :active`; on failure the loop stays `draft` with an error flash. The edit view shows an "Activate" button (draft) or an "Active" badge (active). `LoopsController#deactivate` (`POST /loops/:id/deactivate`) flips an active loop to `status: :closed` (keeping its `agent_id`, so re-activation reuses the existing agent). The activate/deactivate branching lives in private `activation_outcome`/`activate_loop!`/`deactivation_outcome` helpers. Full design in `docs/superpowers/specs/2026-07-14-activate-loop-provision-agent-design.md`.
- `RespondentsController` is the **public respondent voice flow** (`skip_before_action :authenticate_user!`). `GET /i/:slug` (`respondent_path`) looks the loop up by `slug` and renders `show` for `active?` loops or the `closed` view otherwise. `GET /i/:slug/signed_url` (`respondent_signed_url_path`) fetches a fresh ElevenLabs signed conversation URL for `@loop.agent_id` (guarded — `head :not_found` unless `active?`). The `interview_controller.js` Stimulus controller fetches that signed URL, then opens a browser voice session via the `@elevenlabs/client` importmap package, surfacing every failure in an `aria-live` status element.

Not built yet (deferred, in rough order): **ingesting transcripts** back as `Feedback` (webhook — the respondent conversation happens, but nothing captures it yet), **generating `Insight`s** from transcripts (LLM), and **re-sync** (pushing question edits to an already-active agent — currently the live prompt drifts after activation).

## Commands

Ruby 3.3.5, Rails 8.1, PostgreSQL. Use the `bin/` wrappers.

```bash
bin/setup                 # install deps, prepare DB, boot (--skip-server to skip boot)
bin/dev                   # run the dev server (alias for bin/rails server)
bin/rails db:seed:replant # wipe and reseed (db/seeds.rb: founder user + sample loops)

bin/rails test                              # run all tests (Minitest)
bin/rails test test/models/loop_test.rb     # single file
bin/rails test test/models/loop_test.rb:7   # single test by line number
bin/rails test:system                       # Capybara/Selenium system tests

bin/rubocop               # lint (rubocop-rails-omakase, see .rubocop.yml)
bin/brakeman              # security static analysis
bin/bundler-audit         # gem CVE audit
bin/ci                    # run the full CI pipeline locally (see config/ci.rb)
```

`bin/ci` is the source of truth for CI: setup → rubocop → bundler-audit → importmap audit → brakeman → `bin/rails test` → seed replant. Run it before considering work done.

## Architecture notes

- **Auth**: Devise (`:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`). `ApplicationController` enforces `authenticate_user!` globally — each new controller is authenticated by default; use `skip_before_action :authenticate_user!` for public actions (as `PagesController#home` and `RespondentsController#show`/`#signed_url` do). Public actions that read a loop must guard on `active?` themselves (the respondent flow returns the `closed` view / `head :not_found` for non-active loops) — there is no auth wall to lean on.
- **Loop.slug** is generated by `has_secure_token :slug` (unique index) and is the lookup key for both the analyse dashboard (`/analyse/:slug`, auth-gated) and the public respondent flow (`/i/:slug`). `Loop.status` is `enum :status, { draft: 0, active: 1, closed: 2 }` (integer column, default 0); loops start `draft`, are flipped to `active` by `LoopsController#activate` once their voice agent is provisioned, and back to `closed` by `#deactivate`. `Loop` also declares `accepts_nested_attributes_for :questions, allow_destroy: true` with a `reject_if` that drops blank new questions, so loop forms manage their ordered `Question`s (ordered by `position`) inline. `questions_form_controller.js` (Stimulus) drives add/remove/reorder of question fields client-side, setting `position` and toggling `_destroy`.
- **Routes**: `config/routes.rb` has a single `resources :loops` block with `member { post :activate; post :deactivate }` (`activate_loop_path` / `deactivate_loop_path`), the public respondent routes `get "i/:slug"` (`respondent_path`) and `get "i/:slug/signed_url"` (`respondent_signed_url_path`), and the analyse routes (`analyse_index_path` / `analyse_path`).
- **Seeds**: `db/seeds.rb` is populated (a founder user + example loops/questions/feedback) and idempotent; `db:seed:replant` wipes and reloads it.
- **Frontend**: importmap-rails + Turbo + Stimulus (no Node build — npm packages are pinned into `config/importmap.rb`, e.g. `@elevenlabs/client` for the respondent voice session). Stimulus controllers live in `app/javascript/controllers/` (`interview` drives the voice flow, `questions_form` the nested-question editor, `clipboard`/`range_filter` support share links and analyse filters). Styling is Bootstrap 5.3 + Font Awesome via `sassc-rails`; SCSS is organized under `app/assets/stylesheets/{config,components,pages}` and imported through `application.scss`. Forms use `simple_form`.
- **Background/infra**: Solid Queue (jobs), Solid Cache, Solid Cable — all database-backed, no Redis. Relevant when adding async work (e.g. generating insights from feedback). Separate schemas: `db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`.
- **Deploy**: Kamal (Docker) via `config/deploy.yml` and `.kamal/`; Thruster fronts Puma in the container.

## Conventions

`.rubocop.yml` is a **custom** config (not rubocop-rails-omakase, despite `bin/rubocop` pulling omakase in) with `NewCops: enable`. It excludes `test/`, `config/`, `db/`, `bin/`, and a few others; disables `Style/StringLiterals`, `Style/FrozenStringLiteralComment`, `Metrics/AbcSize`, `Metrics/CyclomaticComplexity`, and several other cops; and sets line length to 120. Note `Metrics/MethodLength` (max 10) and `Metrics/ClassLength` (max 100) **are** on — keep methods short. The repo is not currently offense-free (`app/controllers/analyse_controller.rb` has pre-existing offenses); avoid adding new ones. Match surrounding style; run `bin/rubocop` before committing.

**Testing gotcha**: the bundled minitest (6.x) ships no `Mock`/`stub`, and no mocking gem is installed. `test/test_helper.rb` provides a small `stub_instance_method(klass, name, replacement) { ... }` helper (swap-and-restore) for stubbing at a seam — use it (e.g. stub `ElevenLabsAgentCreator#call` or its private `#post`) rather than reaching for `.stub`.
