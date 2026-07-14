# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**loop-ai** — a Rails 8.1 app for collecting and analyzing feedback via "loops". A `User` owns `Loop`s; each loop has ordered `Question`s, collects `Feedback` (respondent transcripts), and produces an `Insight` (sentiment + summary). The AI angle — turning raw feedback transcripts into insights — is the focus of active work (branch `feature/lennart-ai-agent-research`).

The app is early-stage scaffolding. `resources :loops` is routed and `LoopsController` has `new`/`create` stubs; the `Questions`, `Feedbacks`, and `Insights` controllers are still empty with no routes. Expect to build out controllers, actions, and views from scratch. A `loops.agent_id` (string) column has been added to associate each loop with an AI agent — the anchor for the feedback-to-insight work on `feature/lennart-ai-agent-research`.

## Commands

Ruby 3.3.5, Rails 8.1, PostgreSQL. Use the `bin/` wrappers.

```bash
bin/setup                 # install deps, prepare DB, boot (--skip-server to skip boot)
bin/dev                   # run the dev server (alias for bin/rails server)
bin/rails db:seed:replant # wipe and reseed (seeds.rb is currently empty)

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

- **Auth**: Devise (`:database_authenticatable, :registerable, :recoverable, :rememberable, :validatable`). `ApplicationController` enforces `authenticate_user!` globally — each new controller is authenticated by default; use `skip_before_action :authenticate_user!` for public actions (as `PagesController#home` does).
- **Loop.slug** has a unique index — expect slug-based public URLs (`/loops/:slug`) for respondents. `Loop.status` is an `enum :status, { draft: 0, on_air: 1 }` (integer column, default 0). `Loop` also declares `accepts_nested_attributes_for :questions, allow_destroy: true`, so loop forms manage their ordered questions inline.
- **Frontend**: importmap-rails + Turbo + Stimulus (no Node build). Stimulus controllers live in `app/javascript/controllers/`. Styling is Bootstrap 5.3 + Font Awesome via `sassc-rails`; SCSS is organized under `app/assets/stylesheets/{config,components,pages}` and imported through `application.scss`. Forms use `simple_form`.
- **Background/infra**: Solid Queue (jobs), Solid Cache, Solid Cable — all database-backed, no Redis. Relevant when adding async work (e.g. generating insights from feedback). Separate schemas: `db/queue_schema.rb`, `db/cache_schema.rb`, `db/cable_schema.rb`.
- **Deploy**: Kamal (Docker) via `config/deploy.yml` and `.kamal/`; Thruster fronts Puma in the container.

## Conventions

`.rubocop.yml` (omakase) disables `Style/StringLiterals` and `Style/FrozenStringLiteralComment` and sets line length to 120. Match surrounding style; run `bin/rubocop` before committing.
