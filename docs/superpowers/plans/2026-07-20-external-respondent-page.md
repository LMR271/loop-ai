# External Respondent Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the public `/i/:slug` respondent flow its own chrome-free, loop-owner-branded page centered on an animated, state-reactive "lava lamp" orb, plus a thank-you end state.

**Architecture:** A dedicated Rails layout (`respondent`) replaces the app shell for `RespondentsController` (no navbar/sidebar/login). The orb is the Start control and the live-state indicator, driven by CSS classes that the existing `interview` Stimulus controller toggles at each ElevenLabs lifecycle hook. The orb's modern CSS ships as a plain `.css` file linked only on this layout, bypassing the app's old libsass compiler.

**Tech Stack:** Rails 8.1, ERB layouts, Sprockets (plain CSS for the orb), Stimulus + `@elevenlabs/client` (importmap), Bootstrap 5.3 utilities, Minitest.

## Global Constraints

- Ruby 3.3.9, Rails 8.1, Minitest (no `Mock`/`stub` — use `stub_instance_method` from `test/test_helper.rb`).
- `.rubocop.yml` custom config: line length 120, `Metrics/MethodLength` max 10, `Metrics/ClassLength` max 100. Run `bin/rubocop` before committing; add no new offenses.
- Respondent actions are public: `RespondentsController` already uses `skip_before_action :authenticate_user!, only: %i[show signed_url]`. Do not change access control.
- Loop-owner branding only on this page — no LoopAI logo, no "Log in"/"Sign up", no "Powered by".
- Orb: light page, **softened** (reduced blur/spread, gentle shadow). Honor `prefers-reduced-motion`. The orb is a visual enhancement; call state is also announced via the existing `aria-live` status element.
- Orb exotic CSS (`@property`, `color-mix`, `conic-gradient`) goes in a plain `.css` file, NOT through `sassc`/`application.scss`.
- Tests must run green except the known-stale `PagesControllerTest#test_signed-in_visitors_can_view_the_landing_page` (pre-existing failure on `master`, not ours).

---

### Task 1: Chrome-free respondent layout

Give `RespondentsController` its own minimal layout so `show` and `closed` render without the app navbar/sidebar/login links.

**Files:**
- Create: `app/views/layouts/respondent.html.erb`
- Modify: `app/controllers/respondents_controller.rb:1-2`
- Test: `test/controllers/respondents_controller_test.rb`

**Interfaces:**
- Consumes: nothing new.
- Produces: a `respondent` layout with a `<main class="respondent-page">` wrapper and a `<%= yield %>`; loads `stylesheet_link_tag "application"` and `stylesheet_link_tag "respondent"` (the latter created in Task 3) plus `javascript_importmap_tags`.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/respondents_controller_test.rb`, inside the class:

```ruby
test "show renders without app chrome (no login/signup links)" do
  get respondent_url(@loop.slug)

  assert_response :success
  assert_no_match(/Sign up/, response.body)
  assert_no_match(/Log in/, response.body)
  assert_match(/Onboarding feedback/, response.body) # loop-owner branding stays
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/respondents_controller_test.rb -n "/show renders without app chrome/"`
Expected: FAIL — the current `application` layout renders `shared/navbar`, so the body contains "Log in"/"Sign up".

- [ ] **Step 3: Create the layout**

Create `app/views/layouts/respondent.html.erb`:

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= content_for(:title) || @loop&.name || "Interview" %></title>
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Next:wght@400;500;600;700&display=swap" rel="stylesheet">

    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "respondent", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="respondent-body">
    <%= render "shared/flashes" %>

    <main class="respondent-page">
      <%= yield %>
    </main>
  </body>
</html>
```

- [ ] **Step 4: Point the controller at the layout**

In `app/controllers/respondents_controller.rb`, add the `layout` declaration directly under the class definition:

```ruby
class RespondentsController < ApplicationController
  layout "respondent"
  skip_before_action :authenticate_user!, only: %i[show signed_url]
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/respondents_controller_test.rb -n "/show renders without app chrome/"`
Expected: PASS.

Note: `stylesheet_link_tag "respondent"` references a file created in Task 3. Sprockets raises on a missing asset. If you run the full app before Task 3, create an empty `app/assets/stylesheets/respondent.css` now (`touch app/assets/stylesheets/respondent.css`) — Task 3 fills it in. The controller test above does not render assets through Sprockets in the same way, but create the empty file now to be safe.

- [ ] **Step 6: Run rubocop and commit**

Run: `bin/rubocop app/controllers/respondents_controller.rb`
Expected: no new offenses.

```bash
git add app/views/layouts/respondent.html.erb app/controllers/respondents_controller.rb test/controllers/respondents_controller_test.rb app/assets/stylesheets/respondent.css
git commit -m "Give respondent flow a chrome-free layout"
```

---

### Task 2: Orb markup, end control, and thank-you block in the show view

Replace the plain Start button with the orb (the play button inside it is the Start control), add a small End control for use mid-call, and add a hidden thank-you block.

**Files:**
- Modify: `app/views/respondents/show.html.erb`
- Test: `test/controllers/respondents_controller_test.rb`

**Interfaces:**
- Consumes: the `interview` Stimulus controller (Task 4) via `data-interview-target` / `data-action` attributes.
- Produces: DOM targets `orb`, `startButton` (the play button), `endButton`, `status`, `thankYou` on the `interview` controller element.

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/respondents_controller_test.rb`:

```ruby
test "show renders the orb start control and a hidden thank-you block" do
  get respondent_url(@loop.slug)

  assert_response :success
  assert_match(/class="[^"]*\borb\b/, response.body)
  assert_match(/data-interview-target="thankYou"/, response.body)
  assert_match(/you can close this tab/i, response.body)
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/respondents_controller_test.rb -n "/orb start control/"`
Expected: FAIL — the current view has a `btn btn-primary` Start button and no orb/thank-you.

- [ ] **Step 3: Rewrite the show view**

Replace the entire contents of `app/views/respondents/show.html.erb` with:

```erb
<div class="respondent-card" data-controller="interview" data-interview-slug-value="<%= @loop.slug %>">
  <header class="respondent-card__brand text-center">
    <% if @loop.logo_url.present? %>
      <img src="<%= @loop.logo_url %>" alt="<%= @loop.name %>" class="respondent-logo">
    <% end %>
    <h1 class="respondent-card__title"><%= @loop.name %></h1>
    <p class="respondent-card__lead"><%= @loop.description %></p>
  </header>

  <div class="orb is-idle" data-interview-target="orb">
    <button type="button"
            class="orb__play"
            data-action="click->interview#start"
            data-interview-target="startButton"
            aria-label="Start interview">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5v14l11-7z"></path></svg>
    </button>
  </div>

  <p data-interview-target="status" class="respondent-status" role="status" aria-live="polite"></p>

  <button type="button"
          class="btn btn-outline-secondary btn-sm respondent-end"
          data-action="click->interview#end"
          data-interview-target="endButton"
          hidden>
    End interview
  </button>

  <div class="respondent-thankyou text-center" data-interview-target="thankYou" hidden>
    <h2>Thanks for your feedback!</h2>
    <p class="text-muted">Your response has been recorded — you can close this tab now.</p>
  </div>

  <p class="respondent-meta text-muted">
    <small><%= pluralize(@loop.questions.count, "question") %></small>
  </p>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/respondents_controller_test.rb -n "/orb start control/"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/views/respondents/show.html.erb test/controllers/respondents_controller_test.rb
git commit -m "Add orb start control, end button, and thank-you block to respondent view"
```

---

### Task 3: Respondent page + orb styles (plain CSS)

Create the plain-CSS stylesheet: centered light page, softened orb, its `@property` animation, per-state classes, and reduced-motion support. Plain `.css` so libsass never touches it.

**Files:**
- Create/replace: `app/assets/stylesheets/respondent.css` (the empty file from Task 1)

**Interfaces:**
- Consumes: the state classes toggled by Task 4 — `is-idle`, `is-connecting`, `is-listening`, `is-speaking`, `is-ended` on the `.orb` element.
- Produces: visual styling only; no JS/Ruby interface.

- [ ] **Step 1: Write the stylesheet**

Replace the contents of `app/assets/stylesheets/respondent.css` with:

```css
/* Respondent (external interview) page — plain CSS on purpose.
   Uses @property / color-mix / conic-gradient, which the app's libsass
   (sassc 2.4.0) cannot compile. Loaded only on the respondent layout. */

@property --orb-color   { syntax: "<color>";  initial-value: #6c8cff; inherits: true; }
@property --orb-angle   { syntax: "<angle>";  initial-value: -90deg;  inherits: true; }
@property --orb-blur    { syntax: "<length>"; initial-value: 14px;    inherits: true; }
@property --orb-spread  { syntax: "<length>"; initial-value: 2px;     inherits: true; }

.respondent-page {
  min-height: 100vh;
  display: grid;
  place-content: center;
  padding: 2rem 1rem;
  background: #f7f8fb;
}

.respondent-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.25rem;
  max-width: 30rem;
  text-align: center;
}

.respondent-logo { max-height: 48px; width: auto; margin-bottom: .5rem; }
.respondent-card__title { font-size: 1.6rem; margin: 0; }
.respondent-card__lead { color: #55607a; margin: 0; }
.respondent-status { min-height: 1.5rem; font-weight: 600; margin: 0; }
.respondent-meta { margin: 0; }

/* --- Orb ------------------------------------------------------------- */
.orb {
  --size: 180px;
  --lighter-color: color-mix(in srgb, var(--orb-color) 65%, white);
  --darker-color:  color-mix(in srgb, var(--orb-color) 70%, #1b2340);

  position: relative;
  width: var(--size);
  height: var(--size);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 8px solid transparent;
  background:
    radial-gradient(var(--orb-color), var(--orb-color)) no-repeat 50% 50% / 60% 60%,
    linear-gradient(#fff, #fff) padding-box,
    conic-gradient(from var(--orb-angle) at 50% 50%,
      color-mix(in srgb, var(--lighter-color), transparent) 0 72deg,
      var(--darker-color) 100deg 180deg,
      transparent 288deg,
      color-mix(in srgb, var(--lighter-color), transparent)) border-box;
  background-blend-mode: overlay, normal, normal;
  /* softened halo for a light page */
  box-shadow: 0 0 var(--orb-blur) var(--orb-spread)
              color-mix(in srgb, var(--orb-color) 45%, transparent);
  animation: orb-color 12s linear infinite, orb-spin 6s linear infinite;
}

.orb__play {
  border: 0;
  background: rgba(255, 255, 255, .85);
  color: #1b2340;
  width: 64px;
  height: 64px;
  border-radius: 50%;
  display: grid;
  place-content: center;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(27, 35, 64, .18);
}
.orb__play svg { width: 26px; height: 26px; fill: currentColor; }
.orb__play:focus-visible { outline: 3px solid #1b2340; outline-offset: 3px; }

@keyframes orb-color {
  0%   { --orb-color: #6c8cff; }
  25%  { --orb-color: #48c6ef; }
  50%  { --orb-color: #7b5cff; }
  75%  { --orb-color: #ff7eb3; }
  100% { --orb-color: #6c8cff; }
}
@keyframes orb-spin {
  0%   { --orb-angle: -90deg; --orb-blur: 14px; --orb-spread: 2px; }
  50%  {                      --orb-blur: 22px; --orb-spread: 4px; }
  100% { --orb-angle: 270deg; }
}

/* --- Orb states ----------------------------------------------------- */
/* idle: calm and slow, invites a click */
.orb.is-idle { animation-duration: 18s, 10s; }
/* connecting: brief energetic cue while we fetch the signed URL */
.orb.is-connecting { animation-duration: 6s, 2.5s; }
/* listening: gentle, slow pulse — "your turn" */
.orb.is-listening { animation-duration: 14s, 7s; }
/* speaking: faster, more alive — the agent is talking */
.orb.is-speaking { animation-duration: 6s, 2.5s; }
/* ended: settle to a muted, still state */
.orb.is-ended {
  animation-play-state: paused;
  --orb-color: #9aa4c0;
  filter: saturate(.4);
}

.respondent-end { margin-top: -.25rem; }
.respondent-thankyou h2 { font-size: 1.4rem; }

@media (prefers-reduced-motion: reduce) {
  .orb { animation: none; }
}
```

- [ ] **Step 2: Verify the asset pipeline accepts it**

Run: `bin/rails runner "puts Rails.application.assets_manifest.assets.present? || 'manifest-ok'; Sprockets::Railtie.instance rescue nil; puts 'loaded'"`
If that runner form is awkward in your Sprockets version, instead precompile to confirm no pipeline error:
Run: `bin/rails assets:precompile 2>&1 | tail -5 && bin/rails assets:clobber`
Expected: precompile completes without error and lists `respondent-<digest>.css`.

- [ ] **Step 3: Verify in the browser (visual)**

Run the server (`bin/dev`), seed if needed (`bin/rails db:seed:replant`), open an active loop's `/i/:slug`. Expected: a centered light page with the loop's name and a glowing, slowly color-shifting orb with a play triangle. No navbar, no login links.

- [ ] **Step 4: Commit**

```bash
git add app/assets/stylesheets/respondent.css
git commit -m "Style respondent page and softened state-reactive orb (plain CSS)"
```

---

### Task 4: Drive orb state + thank-you from the Stimulus controller

Wire the orb's state classes and the thank-you reveal into `interview_controller.js` at each ElevenLabs lifecycle hook.

**Files:**
- Modify: `app/javascript/controllers/interview_controller.js`

**Interfaces:**
- Consumes: DOM targets `orb`, `startButton`, `endButton`, `status`, `thankYou` (Task 2); state classes styled in Task 3.
- Produces: no downstream consumer — this is the terminal integration.

- [ ] **Step 1: Rewrite the controller**

Replace the entire contents of `app/javascript/controllers/interview_controller.js` with:

```javascript
import { Controller } from "@hotwired/stimulus"
import { Conversation } from "@elevenlabs/client"

// Drives the public respondent voice interview: fetches a signed URL from our
// server, opens an ElevenLabs conversation, and mirrors the live call state
// onto the orb. Every failure is surfaced in the aria-live status element so
// the respondent is never left staring at a dead orb.
export default class extends Controller {
  static values = { slug: String }
  static targets = ["status", "startButton", "endButton", "orb", "thankYou"]

  static STATES = ["is-idle", "is-connecting", "is-listening", "is-speaking", "is-ended"]

  async start() {
    this.setOrbState("is-connecting")
    this.setStatus("Connecting…")
    this.startButtonTarget.disabled = true

    try {
      const res = await fetch(`/i/${this.slugValue}/signed_url`)
      if (!res.ok) throw new Error(`server responded ${res.status} when requesting a signed URL`)

      const { signed_url: signedUrl } = await res.json()
      if (!signedUrl) throw new Error("the server did not return a signed URL")

      this.conversation = await Conversation.startSession({
        signedUrl,
        onConnect: () => this.connected(),
        onDisconnect: () => this.finished(),
        onError: (message) => this.setStatus(`Error: ${message}`),
        onModeChange: ({ mode }) => this.modeChanged(mode)
      })
    } catch (error) {
      this.failedToStart(`Couldn't start the interview: ${error.message}`)
    }
  }

  async end() {
    this.setStatus("Ending…")
    try {
      await this.conversation?.endSession()
      // onDisconnect → finished() resets the UI; finished() here covers no-session.
    } catch (error) {
      this.setStatus(`Couldn't end cleanly: ${error.message}`)
    }
  }

  connected() {
    this.setOrbState("is-listening")
    this.setStatus("Connected — start talking!")
    this.startButtonTarget.hidden = true
    this.endButtonTarget.hidden = false
  }

  modeChanged(mode) {
    if (mode === "speaking") {
      this.setOrbState("is-speaking")
      this.setStatus("Agent is speaking…")
    } else {
      this.setOrbState("is-listening")
      this.setStatus("Listening…")
    }
  }

  // A conversation that actually connected has ended: thank the respondent.
  finished() {
    if (!this.conversation) return // already handled / never connected
    this.conversation = null
    this.setOrbState("is-ended")
    this.setStatus("")
    this.startButtonTarget.hidden = true
    this.endButtonTarget.hidden = true
    if (this.hasThankYouTarget) this.thankYouTarget.hidden = false
  }

  // start() failed before/while connecting: return to idle, keep Start available.
  failedToStart(message) {
    this.conversation = null
    this.setOrbState("is-idle")
    this.setStatus(message)
    this.startButtonTarget.hidden = false
    this.startButtonTarget.disabled = false
    this.endButtonTarget.hidden = true
  }

  setOrbState(state) {
    if (!this.hasOrbTarget) return
    this.orbTarget.classList.remove(...this.constructor.STATES)
    this.orbTarget.classList.add(state)
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
```

- [ ] **Step 2: Verify in the browser (manual — voice flow can't be unit-tested)**

Running a real session needs ElevenLabs + a microphone, so there is no automated assertion here. Run `bin/dev`, open an active loop's `/i/:slug`, and confirm:
- Idle: orb glows calm and slow.
- Click play → orb speeds up ("Connecting…"), then settles to a gentle pulse once connected, End button appears.
- While the agent speaks, the orb is visibly more active; while listening, it calms.
- End the call → orb goes muted/still, the "Thanks for your feedback! … you can close this tab now" block appears, Start/End are gone.
- Deny the mic or kill the network before connecting → status shows the error and the play button stays available (no thank-you).

- [ ] **Step 3: Run the full respondent test file**

Run: `bin/rails test test/controllers/respondents_controller_test.rb`
Expected: PASS (the JS change doesn't affect these, but confirm nothing regressed).

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/interview_controller.js
git commit -m "Mirror live call state onto the orb and reveal thank-you on finish"
```

---

### Task 5: Full-suite verification

- [ ] **Step 1: Run the whole test suite**

Run: `bin/rails test`
Expected: green except the known-stale `PagesControllerTest#test_signed-in_visitors_can_view_the_landing_page` (pre-existing on `master`, documented in CLAUDE.md). If anything else fails, it's ours — fix before finishing.

- [ ] **Step 2: Lint**

Run: `bin/rubocop app/controllers/respondents_controller.rb`
Expected: no new offenses. (Views/CSS/JS are outside rubocop's scope per `.rubocop.yml`.)

- [ ] **Step 3: Final manual pass**

Confirm the four states (idle → connecting → listening/speaking → ended) once more in the browser, and that the `closed` view (a draft loop) also renders chrome-free in the new layout.

---

## Self-Review

**Spec coverage:**
- Chrome-free layout → Task 1. ✓
- `layout "respondent"` on controller → Task 1. ✓
- Loop-owner branding retained → Task 2 (`respondent-card__brand`). ✓
- Thank-you + close hint → Task 2 (markup) + Task 4 (reveal). ✓
- Orb as Start control + state-reactive → Task 2/3/4. ✓
- Light page, softened orb → Task 3. ✓
- `prefers-reduced-motion` → Task 3. ✓
- Error-vs-thank-you distinction → Task 4 (`failedToStart` vs `finished`). ✓
- Controller tests for chrome + orb markup → Task 1/2. ✓
- Divergence: orb CSS is plain `.css`, not `_respondent.scss` — documented (libsass constraint). The `closed` view needs no new markup; it inherits the layout.

**Placeholder scan:** none — all steps carry real code and exact commands.

**Type/name consistency:** targets `orb`, `startButton`, `endButton`, `status`, `thankYou` match between the view (Task 2) and controller (Task 4); state classes `is-idle/is-connecting/is-listening/is-speaking/is-ended` match between CSS (Task 3) and `STATES` (Task 4); `stylesheet_link_tag "respondent"` (Task 1) matches `respondent.css` (Task 3).
