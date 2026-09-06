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

- New Shiny inputs for tour lifecycle and reason detection, fixing
  upstream JohnCoene/cicerone#59, #62 and #69 (upstream is archived; these
  are fixed here, in the fork, only):
  - `{id}_cicerone_started`: fires once per `$start()`, with the 0-based
    `index` and `total_steps` of the first highlighted step. A later
    `$move_to()` does not re-fire it.
  - `{id}_cicerone_ended`: fires whenever a tour is destroyed, with
    `reason` (`"done"`, `"close"`, `"programmatic"` or `"dismissed"`) and
    `completed` (`TRUE` exactly when `reason` is `"done"`), plus `index`
    and `total_steps`. `reason` distinguishes the Done button, the close
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
