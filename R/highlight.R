#' Highlight & Initialise
#'
#' Initialise and highlight an element.
#'
#' @param el Selector of the element to be highlighted, e.g.: an id.
#' @param id Unique identifier of cicerone.
#' @param title Title on the popover.
#' @param description Body of the popover.
#' @param position Deprecated, use `side` and `align`. See the side
#' and alignment section.
#' @param side Side the popover is positioned on: `"left"`, `"right"`,
#' `"top"` or `"bottom"`.
#' @param align Alignment of the popover along the chosen side:
#' `"start"`, `"center"` or `"end"`.
#' @param class className to wrap this specific popover, in addition
#' to the general `popover_class` passed to [initialise()].
#' @param show_btns Whether to show control buttons, `TRUE`/`FALSE`, or a
#' character vector of buttons to show among `"next"`, `"previous"`,
#' and `"close"`.
#' @param disable_buttons Character vector of buttons to render disabled.
#' @param close_btn_text Deprecated: driver.js 1.x renders the close
#' button as an x icon, it no longer has text.
#' @param next_btn_text Next button text.
#' @param prev_btn_text Previous button text.
#' @param done_btn_text Text on the final button.
#' @param stage_background Deprecated: driver.js 1.x cuts the highlighted
#' element out of an SVG overlay, there is no stage element to color.
#' @param animate Whether to animate or not.
#' @param opacity Deprecated, use `overlay_opacity`.
#' @param padding Deprecated, use `stage_padding`.
#' @param allow_close Whether clicking on the overlay should close the tour.
#' @param overlay_click_next Deprecated, use `overlay_click_behavior`.
#' @param overlay_color Color of the page overlay, e.g.: `"#000"`.
#' @param overlay_opacity Opacity of the page overlay, between 0 and 1.
#' @param overlay_click_behavior What clicking the overlay does: `"close"`
#' (default), `"nextStep"`, or a string of JavaScript defining a custom
#' handler.
#' @param smooth_scroll Whether to smooth scroll to the highlighted element.
#' @param stage_padding Distance between the highlighted element and the
#' edge of the cutout, in pixels.
#' @param stage_radius Corner radius of the cutout, in pixels.
#' @param popover_class Class added to all popovers, for custom styling.
#' @param popover_offset Distance between popover and highlighted
#' element, in pixels.
#' @param keyboard_control Allow controlling through keyboard (escape
#' to close, arrow keys to move).
#' @param session A valid Shiny session if `NULL`
#' the function attempts to get the session with
#' [shiny::getDefaultReactiveDomain()].
#' @inheritParams cicerone_params
#'
#' @section Side and alignment:
#' driver.js 1.x positions popovers with `side` (`left`, `right`, `top`,
#' `bottom`) and `align` (`start`, `center`, `end`). `highlight()`
#' always requires `el`; for a centred popover with no target element,
#' use `Cicerone$step()` instead and omit `el` there — driver.js
#' renders it over the page. The pre-2.0.0 `position` values (e.g.:
#' `left-center`, `top-right`, `mid-center`) are still accepted and
#' mapped automatically.
#'
#' @name highlight
#' @export
highlight <- function(el, id, title = NULL, description = NULL, position = NULL,
  class = NULL, show_btns = NULL, close_btn_text = NULL,
  next_btn_text = NULL, prev_btn_text = NULL, side = NULL, align = NULL,
  disable_buttons = NULL, done_btn_text = NULL, show_progress = NULL,
  progress_text = NULL, on_popover_render = NULL, on_next = NULL,
  on_prev = NULL, on_close = NULL, on_done = NULL,
  disable_active_interaction = NULL, advance_on_click = NULL,
  skip_missing_element = NULL, wait_for_element = NULL,
  advance_on = NULL, advance_when = NULL, data = NULL,
  session = NULL) {

  if(is.null(session))
    session <- shiny::getDefaultReactiveDomain()

  assertthat::assert_that(!missing(el), msg = "Must pass `el`")
  assertthat::assert_that(!missing(id), msg = "Must pass a unique `id`")

  deprecated_arg(close_btn_text, "close_btn_text")

  el <- prep_element(el)

  popover <- build_popover(
    title = title,
    description = description,
    side = side,
    align = align,
    position = position,
    popover_class = class,
    show_buttons = show_btns,
    disable_buttons = disable_buttons,
    show_progress = show_progress,
    progress_text = progress_text,
    next_btn_text = next_btn_text,
    prev_btn_text = prev_btn_text,
    done_btn_text = done_btn_text,
    on_popover_render = on_popover_render,
    on_next_click = on_next,
    on_prev_click = on_prev,
    on_close_click = on_close,
    on_done_click = on_done
  )

  step <- drop_nulls(list(
    element = el,
    disableActiveInteraction = disable_active_interaction,
    advanceOnClick = advance_on_click,
    skipMissingElement = skip_missing_element,
    waitForElement = wait_for_element,
    advanceOn = normalize_advance_on(advance_on),
    advanceWhen = validate_advance_when(advance_when),
    data = data
  ))
  step$id <- id

  if(length(popover))
    step$popover <- popover

  session$sendCustomMessage("cicerone-highlight-man", step)

  invisible()
}

#' @rdname highlight
#' @export
initialise <- function(id, animate = TRUE, opacity = NULL, padding = NULL,
  allow_close = TRUE, overlay_click_next = NULL, done_btn_text = "Done",
  close_btn_text = NULL, stage_background = NULL, next_btn_text = "Next",
  prev_btn_text = "Previous", show_btns = TRUE, keyboard_control = TRUE,
  overlay_color = NULL, overlay_opacity = .75,
  overlay_click_behavior = NULL, smooth_scroll = FALSE,
  allow_scroll = TRUE,
  stage_padding = 10, stage_radius = NULL,
  disable_active_interaction = FALSE, advance_on_click = NULL,
  skip_missing_element = NULL, wait_for_element = NULL,
  popover_class = NULL, popover_offset = NULL,
  disable_buttons = NULL, show_progress = FALSE, progress_text = NULL,
  duration = NULL,
  on_popover_render = NULL,
  on_highlight_started = NULL, on_highlighted = NULL, on_deselected = NULL,
  on_destroy_started = NULL, on_destroyed = NULL,
  on_next_click = NULL, on_prev_click = NULL,
  on_close_click = NULL, on_done_click = NULL,
  session = NULL) {

  assertthat::assert_that(!missing(id), msg = "Must pass a unique `id`")

  if(is.null(session))
    session <- shiny::getDefaultReactiveDomain()

  deprecated_arg(close_btn_text, "close_btn_text")
  deprecated_arg(stage_background, "stage_background")

  overlay_opacity <- opacity %||% overlay_opacity
  stage_padding <- padding %||% stage_padding

  if(is.null(overlay_click_behavior)) {
    overlay_click_behavior <- "close"
    if(isTRUE(overlay_click_next))
      overlay_click_behavior <- "nextStep"
  }

  globals <- build_config(
    animate = animate,
    overlay_color = overlay_color,
    overlay_opacity = overlay_opacity,
    smooth_scroll = smooth_scroll,
    allow_close = allow_close,
    allow_scroll = allow_scroll,
    overlay_click_behavior = overlay_click_behavior,
    stage_padding = stage_padding,
    stage_radius = stage_radius,
    allow_keyboard_control = keyboard_control,
    disable_active_interaction = disable_active_interaction,
    advance_on_click = advance_on_click,
    skip_missing_element = skip_missing_element,
    wait_for_element = wait_for_element,
    popover_class = popover_class,
    popover_offset = popover_offset,
    show_buttons = show_btns,
    disable_buttons = disable_buttons,
    show_progress = show_progress,
    progress_text = progress_text,
    next_btn_text = next_btn_text,
    prev_btn_text = prev_btn_text,
    done_btn_text = done_btn_text,
    duration = duration,
    on_popover_render = on_popover_render,
    on_highlight_started = on_highlight_started,
    on_highlighted = on_highlighted,
    on_deselected = on_deselected,
    on_destroy_started = on_destroy_started,
    on_destroyed = on_destroyed,
    on_next_click = on_next_click,
    on_prev_click = on_prev_click,
    on_close_click = on_close_click,
    on_done_click = on_done_click
  )

  globals$id <- id

  session$sendCustomMessage("cicerone-init", list(globals = globals, id = id))
  invisible()
}
