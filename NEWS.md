# cicerone 2.1.0 (development)

- Internal `srcjs/` split (`util.js`/`bridge.js`/`tour.js`/`hints.js`) and a
  new shinytest2 end-to-end test harness (`CICERONE_E2E=true`). No
  user-facing change.
- Documentation: `"over"` removed from the documented `side` values on
  `Cicerone$step()` and `highlight()`. It was never functional for a
  step with a real element — driver.js only renders a centred popover
  "over" the page for its own element-less steps, not in response to a
  user-supplied `side`. No code change; for a centred popover, omit
  `el` and use `title`/`description` instead.
- Documentation: `{id}_cicerone_state$previous` is now documented as a
  **deprecated** alias of `highlighted` (it does not hold the
  previously highlighted element, despite the name), kept only for
  cicerone < 2.0.0 compatibility; `before_previous` is the field that
  holds the previously highlighted element. The field itself is
  unchanged.
- Documentation: JavaScript hook callbacks' `opts` argument now
  documents the `index` field driver.js provides, alongside `config`,
  `state`, and `driver`.
- Documentation: `step(show_if = )`'s roxygen now matches the code
  exactly: a requested `$start(step = )` that `show_if` hides starts at
  the next visible step after it; if none follows, it starts at the
  LAST visible step instead of not starting. `{id}_cicerone_event`'s
  `type = "no_visible_steps"` fires only when every step is hidden. No
  code change -- the JS already behaved this way.

- **Behaviour change:** `$move_forward()`/`$move_backward()` now emit
  `{id}_cicerone_next`/`_previous` and the matching `event:"next"`/
  `"previous"` (a state snapshot taken before the move), matching the
  popover's own Next/Previous buttons. Previously these R6 methods sent
  `cicerone-next`/`cicerone-previous` straight to `moveNext()`/
  `movePrevious()`, bypassing the wrapper that emits those inputs
  entirely -- despite both being documented (README, `?cicerone_inputs`)
  as firing them.
- Async safety: a `wait_for_visible` move (the Next/Previous buttons, or
  `$start()`) that is still pending when the tour is reset, destroyed,
  restarted, or superseded no longer acts on completion. A per-id
  navigation-generation counter, bumped on every such event, is captured
  when the wait begins; a stale completion (a generation mismatch) is
  now discarded outright -- no move, no `anchor_timeout` emit -- instead
  of potentially moving a freshly restarted tour or resurrecting one
  that had already ended.
- A step's own `on_highlighted` no longer skips `_state`/`_started`, the
  `started`/`highlighted` events, and the persisted-record writes for
  that step. The bookkeeping driver.js's step-level override used to
  bypass is now shared with the tour-level default (`highlightBookkeeping()`
  in `steps.js`).
- A standalone `highlight()`/`initialise()` call with `progress_style`
  and no preceding `$init()` for the same id now renders the bar/dots,
  instead of silently falling back to plain text.
- `$set_config(progress_style = "text")` now actually reaches JS,
  clearing a live tour's bar/dots progress on the next render.
  Previously an explicit `"text"` was omitted from the payload the same
  way the (irrelevant, already-`"text"`) default is, so it could not be
  used to switch a bar/dots tour back.
- `cicerone-forget`/`$forget()` no longer emits `{id}_cicerone_seen` for
  a tour with no `persist` backend configured; it already had no record
  to clear.
- `wait_for_element()`'s default `id` (a sanitised form of `selector`)
  now strips a leading `#`/`.` before sanitising, so e.g. `selector =
  "#late"` yields `id = "late"` (previously `"_late"`), matching the
  documented example.

- New Shiny inputs for tour lifecycle and reason detection, fixing
  upstream JohnCoene/cicerone#59, #62 and #69 (upstream is archived; these
  are fixed here, in the fork, only):
  - `{id}_cicerone_started`: fires once per `$start()`, with the 0-based
    `index` and `total_steps` of the first highlighted step. A later
    `$move_to()` does not re-fire it.
  - `{id}_cicerone_ended`: fires whenever a tour is destroyed, or a
    `run_once`/persisted-completed `$start()` is refused, with `reason`
    (`"done"`, `"close"`, `"programmatic"`, `"superseded"`,
    `"suppressed"`, or `"dismissed"` -- the last two added later in this
    same release, see `exclusive`/persistence below) and `completed`
    (`TRUE` exactly when `reason` is `"done"`), plus `index` and
    `total_steps`. `reason` distinguishes the Done button, the close
    button, a server-side `$reset()`/`$destroy()`, and everything else
    (Escape, an overlay click, or any other dismissal).
  - `{id}_cicerone_event`: a unified event stream, one input for every
    lifecycle event (`started`, `highlighted`, `next`, `previous`,
    `done`, `close`, `ended`, `hint_opened`, `hint_dismissed`,
    `hint_button`), each with `type`, `index`, `element`, `total_steps`
    and an ISO-8601 `time`. Fires in addition to the specific input above.
  - `{id}_cicerone_reset` and `cicerone_reset` are unchanged: same
    payload (`TRUE`), same firing conditions. Prefer `_ended` for the
    reason a tour stopped.
  - New `$get_started()`/`$get_ended()` methods on `Cicerone`, reading the
    two new inputs. See `?cicerone_inputs` for the full table of every
    Shiny input the package sets.
  - A tour's Done button now works even when only `on_next` (not
    `on_done`) is set on the last step, matching the pre-2.1.0
    `onNextClick` fallback: driver.js 1.x stops calling `onNextClick` on
    the last step once `onDoneClick` is defined anywhere, which cicerone
    now always does internally to detect `reason = "done"`.

- Hints: a hint's `on_button_click` no longer replaces the default
  dismiss-on-click behaviour. Previously, defining `on_button_click` (or
  cicerone's own internal wrapping) meant the hint's popover button
  stopped auto-dismissing the hint, mirroring the `onCloseClick`
  replacement behaviour in driver.js tours; cicerone now calls
  `dismiss()` after the hook runs, unless the hook returns `false`.
- `initialise()` and `highlight()` now accept every option their `Cicerone`/
  `$step()` equivalents accept. `initialise()` gains `allow_scroll`,
  `disable_active_interaction`, `advance_on_click`, `skip_missing_element`,
  `wait_for_element`, `disable_buttons`, `show_progress`, `progress_text`,
  `duration`, and all ten config-level `on_*` hooks. `highlight()` gains
  `show_progress`, `progress_text`, `on_popover_render`, `on_next`,
  `on_prev`, `on_close`, `on_done`, `disable_active_interaction`,
  `advance_on_click`, `skip_missing_element`, `wait_for_element`, and
  `data`.
- `Hints$hint()` gains `on_popover_render`, mapped to the hint popover's
  `onPopoverRender`.
- New read-only getters: `Cicerone$get_id()`, `Cicerone$get_steps()`,
  `Hints$get_id()`, `Hints$get_hints()`.
- New step options `advance_on` and `advance_when` (`step()` and
  `highlight()`), letting a step advance for reasons other than
  clicking the highlighted element:
  - `advance_on`: a selector string (event defaults to `"click"`) or
    `list(el = "...", event = "...")`. Unlike driver.js's own
    `advance_on_click`, which only reacts to the highlighted element,
    `advance_on` reacts to a named event on any element on the page.
  - `advance_when`: a JavaScript predicate `(step, opts) => boolean`,
    evaluated once when the step is highlighted and again on every DOM
    mutation and `input`/`change` event until it returns `true`.
  - Both may be set on the same step; whichever fires first advances
    the tour and disarms the other. For a server-driven alternative,
    use `observeEvent(input$x, tour$move_forward())`.
  - New `_event` type `"advance"`, with `element` the triggering
    selector (`advance_on`) or the currently highlighted element
    (`advance_when`), without the leading `#`.
  - On the last step, either mechanism completes the tour with
    `_ended$reason = "done"`. `$move_forward()` on the last step now
    reports `"done"` as well (driver.js's `moveNext()` destroys directly
    without routing through the Done button's hooks, so cicerone tags
    the reason itself).
- New `progress_style` argument on `Cicerone$new()`/`$step()` and
  `initialise()`/`highlight()`: `"text"` (the default, unchanged), `"bar"`,
  or `"dots"`. A step-level `progress_style` overrides the tour's default
  for that one step. `"bar"`/`"dots"` force `show_progress` on regardless
  of the `show_progress` argument, since the CSS that renders them needs
  driver.js's own progress element in the DOM. Also renders for a
  standalone `highlight()` call made with no preceding `initialise()`/
  `$init()` for the same id.
- New `cicerone_theme()`: emits a `<style>` tag setting the CSS custom
  properties `custom.css` reads for popover surface/text/accent/
  radius/font-size/shadow/button/progress colors, scoped to `.driver-popover`
  or to a `selector` you pass (e.g. a `popover_class`). `preset = "bootstrap"`
  maps every property to the matching bslib/Bootstrap 5.3+ `--bs-*`
  variable, so a themed tour follows the app's bslib theme, including dark
  mode, automatically. With no theme applied, every popover's computed
  style is unchanged from driver.js's own default look.
- `cicerone_theme()` gains typography and layout arguments: `font_family`
  (sets driver.js's own `--driver-popover-font-family` directly, not a
  `--cicerone-*` property), `title_size`, `title_weight`, `line_height`
  (description line height), `btn_font_size`, `btn_border`, `btn_radius`,
  `btn_hover_bg` (one hover color for every footer button), and
  `max_width`. `preset = "bootstrap"` maps `font_family`, `line_height`,
  `btn_font_size`, `btn_border`, `btn_radius`, and `btn_hover_bg` to the
  matching root-scoped `--bs-*` token, so a bootstrap-themed popover
  inherits the app's own font automatically; `title_size`, `title_weight`,
  and `max_width` have no Bootstrap equivalent and are left unset by the
  preset (driver.js's own defaults stand unless passed explicitly).

- **Behaviour change:** `Cicerone$new(exclusive = )` now defaults to
  `TRUE`. Starting a tour destroys every other currently active tour
  first (their `_ended` fires with `reason = "superseded"`). driver.js
  gives each live tour instance its own popover and overlay, and always
  ids the popover element `driver-popover-content`; two tours started at
  once produced duplicate DOM ids and, in at least one consumer, an
  orphaned popover left over from the first tour. Set `exclusive =
  FALSE` to keep the pre-2.1.0 behaviour of overlapping tours.
- New `destroy_all()` function: destroys every active tour on the page in
  one call, regardless of `id`, with `reason = "programmatic"`. A
  session-wide teardown, independent of `exclusive`.
- New `wait_for_visible` argument on `Cicerone$new()` and `$step()`:
  milliseconds to wait, before moving to a step, for its element to not
  just exist but have a non-zero size (e.g. an element in a Shiny tab
  that has not been shown yet). Implemented by cicerone itself (not
  driver.js), so it only gates moves cicerone makes; on timeout it emits
  `{id}_cicerone_event` with `type = "anchor_timeout"` and moves anyway,
  unless `skip_missing_element` applies, in which case the step is
  skipped.
- New `wait_for_element()` function: a standalone element-readiness wait
  that needs no tour, for gating server-side logic on UI that renders
  asynchronously. Result arrives on `{id}_cicerone_anchor` (see
  `?cicerone_inputs`).
- New `_event` types: `"start_failed"` (a tour is active but rendered no
  popover one frame after `$start()`; not retried automatically -- the
  e2e reproduction attempt (chaining a second tour's `$start()` off a
  click observer, modelling NAS's "no-op start" shape) did not observe
  this race in three consecutive runs; see the WP7 report) and
  `"anchor_timeout"` (see `wait_for_visible` above).

- New `Cicerone$set_steps()`: sends the current `$step()`-built list to
  the browser and replaces whatever steps the live tour is driving.
  Typically paired with the new `$clear_steps()` (empties the list,
  chainable): `tour$clear_steps()$step(...)$step(...)$set_steps()`.
  Errors if called before `$init()` (there is no live tour to update).
- New `Cicerone$set_config()`: updates a live tour's configuration after
  `$init()` without rebuilding it, accepting the same named arguments as
  `$new()`. Only the arguments you pass are sent and changed; everything
  else is left as it already is. Steps are unaffected -- use
  `$set_steps()` for those.
- New `step(show_if = )`: a JavaScript predicate
  (`"(step, opts) => boolean"`), re-evaluated against every step on each
  `$start()` (not once at `$init()`), so a predicate reading live
  DOM/input state can show a different set of steps on different runs.
  A step whose predicate returns `false` is skipped for that run and
  does not count towards `total_steps`. A predicate that throws is
  treated as `true` and logged with `console.warn`. New `_event` type
  `"no_visible_steps"`: every step's `show_if` returned `false`, so the
  tour did not start.
- Internal: the per-step/per-config wrapping logic `cicerone-init` used
  inline is now `prepareSteps()`/`prepareConfig()` in a new
  `srcjs/exts/steps.js`, shared with `cicerone-set-steps`/
  `cicerone-set-config` and with `show_if` filtering in `cicerone-start`.
  No user-facing change.
- Tour persistence: `Cicerone$new()` gains `persist` and `version`.
  cicerone now owns the state machine that decides when a persisted
  tour has been seen, run once, or left mid-way -- consumers only
  choose where the record lives.
  - `persist = NULL` (the default): no persistence, nothing changes,
    cicerone never writes a cookie unless asked.
  - `persist = "cookie"`: cicerone manages one cookie named `cicerone`
    (`path=/; SameSite=Lax; max-age=31536000`, plus `Secure` over
    https), a URL-encoded JSON object keyed by tour id, written and
    read entirely client-side. Read it server-side with the new
    `tour_state(session, id)`, a synchronous parse of
    `session$request$HTTP_COOKIE` (the WebSocket handshake header;
    verified against `shiny`'s own `HTTP_*` Rook-style fields) --
    useful for deciding what to render before the new `_seen` input
    (below) arrives. A cookie write made during the live session is
    not visible back in `session$request` until the page reloads; the
    live inputs cover the rest.
  - `persist = list(read = function(id), write = function(id, record),
    forget = function(id))`: a server-side adapter instead of a
    cookie -- e.g. a database, or (see `?Cicerone`'s Persistence
    section for a worked example) `session$userData`. cicerone calls
    `read()` once at `$init()`, `write()` from observers it registers
    internally on the existing `_started`/`_state`/`_ended` inputs, and
    `forget()` from the new `$forget()` method. An error in any
    callback is caught, reported with `warning()`, and does not stop
    the tour. `persist` combined with an auto-generated `id` is a
    `stop()`: persistence needs a stable id across page loads.
  - The record is `list(v, status, idx, n, t)`: `v` the tour's
    `version` at write time, `status` (`"in_progress"`, `"completed"`,
    or `"dismissed"`), `idx` the last 0-based step index shown, `n` how
    many times `$start()` has run, `t` an ISO-8601 UTC timestamp. A
    stored record whose `v` does not match the tour's current
    `version` reads as if there were no record at all -- cicerone does
    not migrate old records.
  - New `{id}_cicerone_seen` input: fires once at `$init()` when
    `persist` is set, with the record or `NULL` (see
    `?cicerone_inputs`).
  - `$init(run_once = TRUE)`: if the persisted record's `status` is
    already `"completed"`, the next `$start()` does not drive the tour
    and `_ended` fires with `reason = "suppressed"` instead (new
    reason, alongside `"superseded"`). `run_once`'s own per-session
    counter (unchanged) still applies on top of this.
  - `$start(step = 1, resume = FALSE)`: with `resume = TRUE`, starts at
    the persisted `idx` instead of `step` when the record's `status` is
    `"in_progress"` (a tour abandoned mid-way, not completed or
    dismissed).
  - New `$forget(session)` method: removes the persisted record (the
    cookie entry, or the adapter's `forget(id)`) and fires `_seen` with
    `NULL`.
  - Both backends write the record with the same field-for-field
    shape for the same sequence of lifecycle events (verified in the
    e2e suite by comparing the cookie's record with the adapter's
    after an identical scripted run).

# cicerone 2.0.0

Major upgrade: the bundled driver.js was updated from 0.9.8 to 1.8.0, a
complete rewrite of the underlying library. Existing cicerone code keeps
working; deprecated arguments are mapped to their driver.js 1.x
equivalent (or ignored with a warning where no equivalent exists).

Even without changing any code, tours look and feel better: the overlay
is now an SVG cutout rather than a stacked CSS stage, so highlighting is
smoother, resize/scroll repositioning is reliable, and popovers place
themselves more intelligently.

## Breaking-ish changes

- `close_btn_text` is deprecated and ignored: the close button is now an
  x icon without text.
- `stage_background` is deprecated and ignored: driver.js 1.x cuts the
  highlighted element out of an SVG overlay, there is no stage element.
- `position` is deprecated in favor of `side` and `align`; old values
  are mapped automatically.
- `opacity`, `padding` and `overlay_click_next` are deprecated in favor
  of `overlay_opacity`, `stage_padding` and `overlay_click_behavior`;
  old arguments are still honored.
- Custom CSS written against driver.js 0.9 selectors (e.g.
  `#driver-page-overlay`, `#driver-highlighted-element-stage`) no longer
  applies: driver.js 1.x uses new class names such as `.driver-popover`
  and `.driver-overlay`, and popovers are best themed via
  `popover_class`.

## New features

- New tour options: `overlay_color`, `smooth_scroll`, `allow_scroll`,
  `stage_radius`,
  `disable_active_interaction`, `advance_on_click`,
  `skip_missing_element`, `wait_for_element`, `popover_class`,
  `popover_offset`, `disable_buttons`, `show_progress`, `progress_text`,
  and `duration`.
- `show_btns` now also accepts a character vector among `"next"`,
  `"previous"`, `"close"`.
- New step options: `side`, `align`, `done_btn_text`, `show_progress`,
  `progress_text`, `disable_buttons`, `disable_active_interaction`,
  `advance_on_click`, `skip_missing_element`, `wait_for_element`, and
  `data`.
- Element-less steps: pass only `title`/`description` to `step()` for a
  modal-like step.
- New tour-level hooks: `on_popover_render`, `on_highlight_started`,
  `on_highlighted`, `on_deselected`, `on_destroy_started`,
  `on_destroyed`, `on_next_click`, `on_prev_click`, `on_close_click`,
  `on_done_click`; new step-level hooks `on_deselected`, `on_prev`,
  `on_close`, `on_done`, `on_popover_render`.
- New methods: `move_to()`, `refresh()`, `destroy()` (alias of
  `reset()`), and `get_state()`.
- New Shiny inputs: `{id}_cicerone_state` (updated on every highlight),
  `{id}_cicerone_reset`, and richer payloads (`index`, `is_first`,
  `is_last`, `has_previous`, `total_steps`) on `{id}_cicerone_next` /
  `{id}_cicerone_previous`.
- New `Hints` class wrapping the driver.js hints module: pulsing beacons
  attached to elements, with `show()`, `hide()`, `open()`, `close()`,
  `dismiss()`, `restore()` and `refresh()` methods and Shiny events
  (`{id}_cicerone_hint_opened`, `{id}_cicerone_hint_dismissed`,
  `{id}_cicerone_hint_button`).
- The driver and hints instances are exposed to host JavaScript as
  `window.cicerone.drivers[id]` and `window.cicerone.hints[id]`, so
  tours can also be driven from custom JavaScript.
- Added a demo application, see
  `shiny::runApp(system.file("examples/demo", package = "cicerone"))`.

## Bug workarounds

- Works around a driver.js 1.8.0 bug where, with `animate = TRUE`,
  advancing before the highlight transition completes leaks the
  `driver-active-element` class (and its `pointer-events: auto`) on
  previously visited elements, leaving them clickable underneath the
  overlay. cicerone now strips stale tags at every highlight start.

# cicerone 1.0.5.9000

- Added `run_once` argument.
- Allow more selectors, no longer limited to `id`.

# cicerone 1.0.5

- Add `cicerone_reset` event
- Use webpack (via {packer}) to optimise JavaScript

# cicerone 1.0.4

- Force `title` and `description` so one can use htmltools tags.
- Support for mathjax, see online guide for details.
 
# cicerone 1.0.3

- Add `tab` and `tab_id` arguments to trigger open tabs.
- Add `is_id` argument to `step` and `highlight` method to allow using other selectors than `#id`, see [#7](https://github.com/JohnCoene/cicerone/issues/7)
- Add `on_highlighted` to run JavaScript functions when the step is highlighted, see [#13](https://github.com/JohnCoene/cicerone/issues/13)
- Added `on_highlight_started` and `on_next` to step functions see [#15](https://github.com/JohnCoene/cicerone/issues/15)

# cicerone 1.0.2

Deprecated the `has_next_step`, `get_previous_el`, and `get_highlighted_el` methods, which were partly broken and mainly inadequate, in favour of `get_next` and `get_previous` methods. They contain all the information that was returned by the methods they deprecate and work better. They are fired when the user clicks next or previous.

# cicerone 1.0.1

* Initial CRAN version
