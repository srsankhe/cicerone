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
