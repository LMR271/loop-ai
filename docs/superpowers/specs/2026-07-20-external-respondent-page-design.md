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
- **Interaction focal point:** an animated **gradient orb** ("lava lamp" color-melt) is
  the centerpiece of the page, so a respondent on a voice-only screen can see something
  is alive and listening. It doubles as the **Start control** (a play button lives inside
  it) and is **state-reactive** — it changes with the live call (see Component 6).
- **Page backdrop:** the page stays **light / branded**; the orb is **softened** (reduced
  blur/spread, gentler shadow) to read well on a light background rather than a dark stage.
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
  `@loop.description`) — this becomes the page's visual identity, above the orb.
- Replace the plain "Start Interview" button with the **orb markup** (Component 6): a
  `.orb` element with a play `<button>` inside it wired to `interview#start` (the orb *is*
  the start control). Keep the `aria-live` status element and question count.
- Provide an **End control** for use during a live call — a small, unobtrusive
  "End interview" button below the orb (a `interview` target, hidden until connected).
- Add a **hidden thank-you block** (a new `interview` Stimulus target) containing the
  thank-you message and the "you can close this tab now" hint. Hidden on load; revealed
  when the interview ends normally.

### 4. `app/javascript/controllers/interview_controller.js` (modified)

- Add targets: `orb`, `thankYou` (plus the existing `status` / start / end controls).
- Drive the orb's visual state by toggling CSS classes on the `orb` target at each
  lifecycle hook (see Component 6 for the state list): `start()` → connecting,
  `onConnect` → listening, `onModeChange` → speaking/listening, `onDisconnect` (normal) →
  ended.
- On normal disconnect (`onDisconnect`), reveal the thank-you block, set the orb to its
  ended state, and hide the start/end controls instead of only re-showing Start.
- Preserve the current error-path behavior: a failure to *start* still surfaces the error
  and returns the orb to idle with Start available (the thank-you state is for a completed
  conversation, not a failed connection). The distinction: `end()` / normal `onDisconnect`
  after a successful connection → thank-you; `start()` failure → error + orb idle.

### 5. `app/assets/stylesheets/pages/_respondent.scss` (new)

A small page partial (imported via `application.scss`, following the existing
`pages/` convention) for the calm, centered respondent layout **and the orb styles**
(Component 6). Bootstrap utilities preferred over bespoke CSS where they suffice.

### 6. Gradient orb (new)

An animated "lava lamp" orb, adapted from the user-supplied reference, that is both the
Start control and the live-state indicator.

- **Technique:** registered CSS custom properties via `@property` (`--color`, `--angle`,
  `--blur`, `--spread`) so the browser interpolates them, producing the smooth color-melt
  and rotating conic-gradient. Browsers without `@property` support degrade to a static
  (non-animated) orb — acceptable, still a visible circle with a play button.
- **Light-background adaptation:** drop the reference's `body { background:#000 }`; reduce
  `--blur` / `--spread` and use a gentler shadow color so the halo reads as a soft light
  source on a light page, not a dark smudge. The play-button icon and any inner treatment
  must have adequate contrast on the light page.
- **States** (CSS classes toggled by the controller on the `orb` target):
  - `idle` — calm/slow (or still) animation, play button visible; the resting invitation.
  - `connecting` — a brief transitional cue while the signed URL is fetched.
  - `listening` — gentle, slow pulse: "I'm here, your turn."
  - `speaking` — more energetic/faster animation: the agent is talking.
  - `ended` — settled, muted state shown alongside the thank-you block.
- **Accessibility:** honor `prefers-reduced-motion` (reduce or stop the animation); the
  play button keeps an `aria-label`; call state continues to be announced via the existing
  `aria-live` status element, so the orb is a visual enhancement, not the only signal.
- Drop the reference demo's embedded Apple-logo background layer — it was placeholder art.

## Data flow

Unchanged from today. `GET /i/:slug` → `RespondentsController#show` → renders `show`
(active) or `closed` (not active) inside the new `respondent` layout. The voice session
still goes: orb play button → `interview_controller#start` → `GET /i/:slug/signed_url` →
ElevenLabs `Conversation.startSession`. New: each lifecycle hook toggles the orb's state
class, and a normal end reveals the thank-you block with the orb in its ended state.

## Error handling

- Loop not found: `Loop.find_by!` still raises `RecordNotFound` → standard 404. Unchanged.
- Loop not active: `show` renders `closed` (now in the respondent layout). Unchanged.
- Interview fails to start: error surfaced in the `aria-live` status element, Start button
  remains available — thank-you is NOT shown. Unchanged from today's error path.

## Testing

- Controller test: `#show` for an active loop renders with the `respondent` layout and
  does **not** contain the app navbar's "Log in" / "Sign up" links or the LoopAI logo.
- Controller test: `#show` for a non-active loop renders `closed`, also without app chrome.
- Controller test: `#show` renders the orb markup (the `.orb` element / play button).
- (Existing respondent/webhook tests must continue to pass.)
- The thank-you reveal and orb state transitions are client-side JS; cover via a system
  test if the suite's Capybara/Selenium setup can drive it, otherwise verify manually in
  the browser. The orb animation itself (CSS `@property`) is visual-only — no automated
  assertion; verify by eye.

## Out of scope

- Access control changes (already public).
- `respondent_email` capture, audio, insights — unrelated deferred work.
- Any change to how loops are provisioned or how transcripts are ingested.
