# Notification bell: per-user "seen" state

## Problem

The bell icon in the navbar shows a red badge and a dropdown of loops with "new" feedback (`unanalyzed_feedback_count`, i.e. `feedbacks.size - insight.analyzed_feedback_count`). Clicking an entry takes you to that loop's analyse page, but nothing marks it as noticed — the entry stays in the dropdown until Stage 2 analysis is actually re-run via the "Refresh" button. There is no "read/dismiss" action; the expectation is that simply visiting the loop should make its notification disappear on its own.

## Design

### Data model

New table `loop_views`:

| column | type | notes |
|---|---|---|
| `user_id` | bigint, FK | who saw it |
| `loop_id` | bigint, FK | which loop |
| `last_seen_feedback_count` | integer, default 0 | `loop.feedbacks.size` as of the last time this user viewed this loop's analyse page |

Unique index on `[user_id, loop_id]`.

New model `LoopView`:

```ruby
class LoopView < ApplicationRecord
  belongs_to :user
  belongs_to :loop
end
```

`User has_many :loop_views, dependent: :destroy` and `Loop has_many :loop_views, dependent: :destroy`.

This is deliberately per-*user*, not per-loop or per-organization: teammates in the same workspace view loops independently, so one teammate opening a loop must not clear the notification for everyone else.

### Marking a loop "seen"

`AnalyseController` sets `@loop` in both `index` (defaults to the most recent loop, then `render :show`) and `show` (looked up by `slug`), and both funnel into `load_shared_data`. That's the single place to stamp "seen": if `@loop` is present, upsert the current user's `LoopView` for it to `@loop.feedbacks.size`, but only when that's higher than what's already stored (a loop can't become "less seen").

No separate dismiss action, no button — visiting the page (from the bell, direct link, or anywhere else) is the entire mechanism.

### Reading "new" for the badge/dropdown

`ApplicationController#loops_with_new_feedback` currently selects loops where `unanalyzed_feedback_count.positive?`. It changes to compare each loop's live feedback count against the *current user's* `last_seen_feedback_count`, loading all of the current user's `LoopView` rows in one query up front (`current_user.loop_views.pluck(:loop_id, :last_seen_feedback_count).to_h`) to avoid N+1s across loops. A loop with no `LoopView` row yet is treated as last-seen `0` — everything about it is new, which is correct for a loop this user has never opened.

`unanalyzed_feedback_total` sums the same per-loop "new since last seen" count instead of `unanalyzed_feedback_count`.

The navbar dropdown (`app/views/shared/_navbar.html.erb`) needs the per-loop new-count alongside each loop, so `loops_with_new_feedback` returns loops and a second helper (or a memoized hash) supplies the count per loop for the `pluralize(..., "new response")` text.

### What does NOT change

`Loop#unanalyzed_feedback_count` (`feedbacks.size - insight.analyzed_feedback_count`) is untouched. It continues to drive the Insight panel's "N new responses since — Refresh to include them" note (`app/views/analyse/_insight_panel.html.erb`), which is about analysis staleness, not view history — a genuinely different concept from "have I personally looked at this loop lately."

### Testing

- Model: `LoopView` uniqueness on `[user_id, loop_id]`.
- Controller/integration: visiting `analyse_path(loop.slug)` as a user with older/no `LoopView` bumps `last_seen_feedback_count` to the loop's current feedback count; a second visit with no new feedback doesn't regress it. Bell helper (`loops_with_new_feedback`, `unanalyzed_feedback_total`) reflects per-user seen state, and is independent across two users in the same organization (one visiting doesn't clear it for the other).
- View: navbar dropdown shows/hides an entry based on the current user's seen state, not another user's.

## Out of scope

- Any explicit "mark all as read" or per-item dismiss control — the ask is specifically that it clears itself on view, no button.
- Changing what `unanalyzed_feedback_count` / the Insight panel staleness note mean.
- Real-time badge updates (e.g. via Turbo Streams/ActionCable) while a user has the page open in another tab — the badge is computed on each request, same as today.
