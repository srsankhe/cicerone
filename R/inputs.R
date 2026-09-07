#' Shiny inputs set by cicerone
#'
#' Every Shiny input the cicerone JavaScript bridge sets, for both
#' [Cicerone] tours and [Hints]. `{id}` is the `id` of the `Cicerone` or
#' `Hints` object. Inputs marked "event" are set with `priority: "event"`
#' (see [shiny::updateActionButton()] and the Shiny documentation on
#' input priority): they fire even if the value is unchanged from the
#' previous time, and are the ones you want in `observeEvent()`.
#'
#' @section Tour inputs:
#' | Input | Event | Payload | Fires |
#' | --- | --- | --- | --- |
#' | `{id}_cicerone_state` | no | `list(highlighted, previous, before_previous, has_next, has_previous, index, is_first, is_last, total_steps)` | every time a step is highlighted |
#' | `{id}_cicerone_next` | yes | same shape as `_state` | the Next button is clicked, `$move_forward()` is called, or a step's `on_next` fires it programmatically |
#' | `{id}_cicerone_previous` | yes | same shape as `_state` | the Previous button is clicked, or `$move_backward()` is called |
#' | `{id}_cicerone_started` | yes | `list(index, total_steps)` | the first step is highlighted after `$start()`; not re-fired by `$move_to()` |
#' | `{id}_cicerone_ended` | yes | `list(reason, completed, index, total_steps)` | the tour is destroyed, for any reason |
#' | `{id}_cicerone_event` | yes | `list(type, index, element, total_steps, time)` | every lifecycle event below, in addition to its specific input |
#' | `{id}_cicerone_reset` | yes | `TRUE` | the tour is destroyed, for any reason (kept for 1.x compatibility; use `_ended` for the reason) |
#' | `cicerone_reset` | yes | `TRUE` | any tour on the page is destroyed (not namespaced by `id`) |
#' | `{id}_cicerone_seen` | yes | the persisted record (`list(v, status, idx, n, t)`), or `NULL` | `$init()`, when `persist` is set (see [Cicerone]); not fired otherwise |
#'
#' `reason` in `_ended` is one of `"done"` (the Done button on the last
#' step), `"close"` (the close button), `"programmatic"` (`$reset()`/
#' `$destroy()` called from the server, or [destroy_all()]),
#' `"superseded"` (another tour started with `exclusive = TRUE` while
#' this one was active, see [Cicerone]), `"suppressed"` (`persist` is
#' set, `$init(run_once = TRUE)`, and the persisted record's `status` is
#' already `"completed"`: the refused `$start()` never drives the tour
#' or creates a popover at all -- `_ended` still fires, with no matching
#' `_started`), or `"dismissed"` (Escape, an overlay click, or anything
#' else).
#' `completed` is `TRUE` exactly when `reason` is `"done"`.
#'
#' `type` in `_event` is one of `"started"`, `"highlighted"`, `"next"`,
#' `"previous"`, `"done"`, `"close"`, `"ended"`, `"hint_opened"`,
#' `"hint_dismissed"`, `"hint_button"`, `"advance"` (a step's
#' `advance_on`/`advance_when` fired, see [Cicerone]'s `step()`),
#' `"start_failed"` (the tour is active but rendered no popover one frame
#' after `$start()`; not retried automatically), `"anchor_timeout"` (a
#' step's `wait_for_visible` timed out; the tour moves to the step anyway
#' unless `skip_missing_element` applies), or `"no_visible_steps"`
#' (`$start()` was called but every step's `show_if` predicate returned
#' `false`; the tour does not start, `index` and `element` are `NULL`,
#' `total_steps` is `0`, see [Cicerone]'s `step()`). `element` is the id
#' of the event's associated element (the highlighted step's element for
#' tour events, the `advance_on` element for an `"advance"` event
#' triggered by it, the hint's element for hint events), or `NULL`.
#' `time` is an ISO-8601 string.
#'
#' @section Hint inputs:
#' | Input | Event | Payload | Fires |
#' | --- | --- | --- | --- |
#' | `{id}_cicerone_hint_opened` | yes | `list(id, element)` | a hint's beacon is clicked, opening its popover |
#' | `{id}_cicerone_hint_dismissed` | yes | `list(id, element)` | a hint is dismissed (its beacon hidden) |
#' | `{id}_cicerone_hint_button` | yes | `list(id, element)` | a hint popover's button is clicked |
#'
#' `id` in the hint payloads is the hint's `hint_id` if it has one,
#' otherwise `NULL`. Every hint event also sets `{id}_cicerone_event`
#' (`type` `"hint_opened"`/`"hint_dismissed"`/`"hint_button"`), with
#' `index` the hint's 0-based position and `total_steps` the number of
#' hints.
#'
#' @section Standalone inputs:
#' | Input | Event | Payload | Fires |
#' | --- | --- | --- | --- |
#' | `{id}_cicerone_anchor` | yes | `list(selector, found, visible, elapsed)` | a [wait_for_element()] call resolves (element found, or `timeout` reached) |
#'
#' `{id}_cicerone_anchor` needs no [Cicerone] or [Hints] object; `id`
#' comes from [wait_for_element()]'s `id` argument (a sanitised form of
#' `selector` by default). `found` is `TRUE` once `selector` matched an
#' element; `visible` is `TRUE` once that element had a non-zero
#' `getBoundingClientRect()`; `elapsed` is milliseconds from the call to
#' resolution.
#'
#' @seealso [Cicerone], [Hints], [destroy_all()], [wait_for_element()], [tour_state()]
#'
#' @name cicerone_inputs
NULL
