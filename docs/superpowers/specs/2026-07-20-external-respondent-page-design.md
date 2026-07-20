# External Respondent Page — Design

**Date:** 2026-07-20
**Branch:** `feature/lennart-external-feedback-link`
**Status:** Approved, pending implementation plan

## Problem

A respondent receives a link (`/i/:slug`) and opens it to talk to the voice agent.
Today that page renders inside `app/views/layouts/application.html.erb`. Because the
respondent is not signed in, the layout's `else` branch (`public-shell`) still renders
`shared/navbar`, which shows the **LoopAI logo** and **"Log in" / "Sign up"** buttons.

The result: a respondent lands on something that looks like *our* app's marketing
surface, with login prompts they will never use. We want the link to feel like a
standalone, external page that belongs to the loop's owner — no LoopAI chrome, no auth
UI. The respondent talks to the agent and closes the tab.

The public, no-login access already works (`RespondentsController` uses
`skip_before_action :authenticate_user!`). This feature is about the **framing** of the
page, not about access control.

## Decisions

- **Branding:** the page reflects the *loop owner's* brand (their `logo_url` + loop
  name/description), not LoopAI's. No LoopAI logo, no "Powered by" credit.
- **End state:** when the interview ends normally, the interview UI is replaced by a
  thank-you message plus a gentle "you can close this tab now" hint.
- **Layout mechanism:** a dedicated Rails layout for the respondent flow (Approach A
  below), chosen over conditionally hiding chrome inside `application.html.erb`.

## Approach (chosen: dedicated layout)

Rails decides which layout wraps a view per-controller. A controller with no `layout`
declaration inherits `application`. Declaring `layout "respondent"` in
`RespondentsController` makes all its actions render inside a new
`app/views/layouts/respondent.html.erb` instead — a minimal, chrome-free shell.

Rejected alternatives:
- **Conditional inside `application.html.erb`** (hide navbar when on a respondent page):
  tangles respondent concerns into the main layout; every future app-chrome change must
  remember the respondent exception.
- **CSS-only chrome hiding:** fragile and semantically wrong — the chrome markup still
  ships to the browser and to assistive tech.

## Components

### 1. `app/views/layouts/respondent.html.erb` (new)

A minimal HTML document:
- Same `<head>` essentials as `application.html.erb`: viewport meta, `csrf_meta_tags`,
  `csp_meta_tag`, `yield :head`, favicon links, Google Fonts preconnect/link,
  `stylesheet_link_tag "application"`, and **`javascript_importmap_tags`** — the voice
  flow depends on the importmap (`@elevenlabs/client`, Stimulus), so this must be present.
- `<body>` renders `shared/flashes` and a single centered `<main>` containing
  `<%= yield %>`. No navbar, no sidebar, no login/signup links.

### 2. `RespondentsController` (modified)

Add `layout "respondent"`. Both `show` and `closed` now render chrome-free. No changes
to `show` / `signed_url` action logic.

### 3. `app/views/respondents/show.html.erb` (modified)

- Keep the existing loop-owner branding block (`@loop.logo_url`, `@loop.name`,
  `@loop.description`) — this becomes the page's visual identity.
- Add a **hidden thank-you block** (a new `interview` Stimulus target) containing the
  thank-you message and the "you can close this tab now" hint. Hidden on load; revealed
  when the interview ends normally.

### 4. `app/javascript/controllers/interview_controller.js` (modified)

- Add a `thankYou` target.
- On normal disconnect (`onDisconnect`), reveal the thank-you block and hide the
  Start/End controls instead of only re-showing the Start button.
- Preserve the current error-path behavior: a failure to *start* still surfaces the error
  and leaves Start available (the thank-you state is for a completed conversation, not a
  failed connection). The distinction: `end()` / normal `onDisconnect` after a successful
  connection → thank-you; `start()` failure → error + Start still available.

### 5. `app/assets/stylesheets/pages/_respondent.scss` (new)

A small page partial (imported via `application.scss`, following the existing
`pages/` convention) for the calm, centered respondent layout. Bootstrap utilities
preferred over bespoke CSS where they suffice.

## Data flow

Unchanged from today. `GET /i/:slug` → `RespondentsController#show` → renders `show`
(active) or `closed` (not active) inside the new `respondent` layout. The voice session
still goes: Start button → `interview_controller#start` → `GET /i/:slug/signed_url` →
ElevenLabs `Conversation.startSession`. New: normal end reveals the thank-you block.

## Error handling

- Loop not found: `Loop.find_by!` still raises `RecordNotFound` → standard 404. Unchanged.
- Loop not active: `show` renders `closed` (now in the respondent layout). Unchanged.
- Interview fails to start: error surfaced in the `aria-live` status element, Start button
  remains available — thank-you is NOT shown. Unchanged from today's error path.

## Testing

- Controller test: `#show` for an active loop renders with the `respondent` layout and
  does **not** contain the app navbar's "Log in" / "Sign up" links or the LoopAI logo.
- Controller test: `#show` for a non-active loop renders `closed`, also without app chrome.
- (Existing respondent/webhook tests must continue to pass.)
- The thank-you reveal is client-side JS; cover via a system test if the suite's
  Capybara/Selenium setup can drive it, otherwise verify manually in the browser.

## Out of scope

- Access control changes (already public).
- `respondent_email` capture, audio, insights — unrelated deferred work.
- Any change to how loops are provisioned or how transcripts are ingested.
