# Activate a loop → provision its ElevenLabs agent

**Date:** 2026-07-14
**Branch:** `feature/lennart-agent-creator`
**Status:** Approved design, ready for implementation plan

## Goal

Finish "stage 2" of the feedback pipeline: let a user turn a draft loop into a
live ElevenLabs voice agent. Today `SystemPromptBuilder` and
`ElevenLabsAgentCreator` exist but nothing calls them, so `loops.agent_id` is
never set. This design wires provisioning into an explicit **activation** action.

## Decisions (settled during brainstorming)

1. **Trigger: on activation.** The agent is created when the user explicitly
   activates a loop — not on create (no questions exist yet) and not on every
   save. Activation also brings the currently-unused `status` enum
   (`draft/active/closed`) to life and becomes the future gate for the public
   respondent flow.
2. **Create-once, no auto-sync.** Activation provisions the agent only if the
   loop has no `agent_id` yet. Editing an active loop's questions/description
   afterward updates the local DB but does **not** call ElevenLabs. Keeping the
   remote prompt in sync is a deferred "Re-sync agent" slice.
3. **Synchronous execution.** The activation request calls ElevenLabs inline and
   shows immediate success/error feedback. No background job — activation is a
   deliberate, low-frequency admin click, and inline execution gives clean,
   honest error reporting (which matters when an external API can fail).

## Flow

```
[Edit loop page] --click "Activate"--> POST /loops/:id/activate
        │
        ▼
LoopsController#activate
   ├─ guard: already active / has agent_id?  → redirect back, notice (no API call)
   ├─ guard: no questions?                    → redirect back, alert (no API call)
   ├─ ElevenLabsAgentCreator.new(loop).call   (synchronous)
   │     success → loop.update!(agent_id:, status: :active) → flash "Loop activated"
   │     failure → rescue domain error → flash "Couldn't create agent: <reason>", stay draft
   └─ redirect back to edit page
```

## Components

### Route
- Add a member route to `resources :loops`: `member { post :activate }`.
- Consolidate the duplicate `resources :loops` declarations in
  `config/routes.rb` into a single block while doing this.

### `LoopsController#activate`
- Loads the loop via `current_user.loops.find(params[:id])` (ownership scoping,
  as the other actions do).
- Guard 1 — **already provisioned**: if `loop.agent_id.present?` (or already
  `active`), redirect back with a `notice`, no API call. This enforces the
  create-once rule.
- Guard 2 — **no questions**: if the loop has no questions, redirect back with an
  `alert`, no API call (the prompt would be empty).
- Calls `ElevenLabsAgentCreator.new(loop).call`.
- On success: `loop.update!(agent_id: <returned id>, status: :active)`, flash
  `notice` "Loop activated."
- On failure: rescue the service's domain error, flash `alert`
  "Couldn't create agent: <reason>"; loop stays `draft`.
- Redirects back to `edit_loop_path(loop)`.

### `ElevenLabsAgentCreator` (hardening)
- Wrap the `RestClient.post` in `begin/rescue` for `RestClient::Exception`
  (and connection errors); add a request timeout.
- Guard a missing/blank `ELEVENLABS_API_KEY` and fail with a clear message
  rather than sending an unauthenticated request.
- Raise a domain error (`ElevenLabsAgentCreator::Error`) carrying a
  human-readable message on any failure, so the controller owns flash wording
  and the service stays focused. Success still returns the `agent_id` string.

### `SystemPromptBuilder`
- Unchanged. Already turns the loop into the prompt string the creator sends.

### UI
- Add an **"Activate"** button on `app/views/loops/edit`, shown while the loop is
  `draft`, that POSTs to the activate route.
- When the loop is `active`, show a static **"Active"** badge instead (no
  deactivate control for now).
- Use existing Bootstrap 5.3 styling; keep it minimal.

## Testing

- **Service test** (`ElevenLabsAgentCreator`): stub HTTP — success returns the
  `agent_id`; a non-2xx / raised `RestClient::Exception` surfaces as the domain
  error; missing API key fails clearly. No real network calls.
- **Controller test** (`#activate`): success path sets `agent_id` and flips
  `status` to `active`; the no-questions guard blocks and flashes without calling
  the API; the already-active guard does not re-call the API.

## Out of scope (deferred slices)

- Re-sync-on-edit (fixing prompt drift on an active loop) — its own "Re-sync
  agent" feature with an ElevenLabs update/PATCH path.
- Deactivate / close a loop.
- Background-job execution (revisit only if latency/reliability demands it).
- The public respondent flow (stage 3) and everything downstream.
```

## Success criteria

- Activating a draft loop with questions creates an ElevenLabs agent, stores its
  `agent_id`, and marks the loop `active`, with a success flash.
- A failed API call leaves the loop `draft` and shows a clear error flash — no
  500.
- Re-activating an already-active loop makes no second API call.
- Activating a loop with no questions is blocked with a clear message.
- New tests pass and `bin/ci` is green.
