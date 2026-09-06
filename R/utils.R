generate_id <- function() {
  paste0(sample(letters, 26), collapse = "")
}

# valid `progress_style` values, shared by `Cicerone$new()`/`initialise()`
# (config-level, always resolved to one of these via `match.arg()`) and
# `step()`/`highlight()` (step-level, where `NULL` means "inherit the
# tour's style" and is validated separately by the caller)
progress_styles <- c("text", "bar", "dots")

# "bar"/"dots" progress needs driver.js's own `showProgress` flag on: the
# bar/dots CSS in custom.css repurposes the `.driver-popover-progress-
# text` node, which driver.js only *shows* (vs. `display: none`) when
# `showProgress` is true. Force it on whenever `progress_style` asks for
# a bar or dots, regardless of what the caller passed for
# `show_progress`, rather than silently no-op the feature.
resolve_show_progress <- function(progress_style, show_progress) {
  if (identical(progress_style, "bar") || identical(progress_style, "dots"))
    return(TRUE)
  show_progress
}

prep_element <- function (el) {
  if (!grepl("(?:^\\.)|(?:^\\#)|<|>|\\[|\\s", el)) paste0("#", el) else el
}

`%||%` <- function(x, y) {
  if (is.null(x))
    y
  else x
}

# drop NULL entries from a list
drop_nulls <- function(x) {
  x[!vapply(x, is.null, logical(1))]
}

# driver.js 1.x expects `showButtons`/`disableButtons` as an array of
# "next", "previous", "close". cicerone < 2.0.0 used a logical `show_btns`;
# both are accepted.
normalize_buttons <- function(x) {
  if (is.null(x)) return(NULL)

  if (is.logical(x)) {
    if (isTRUE(x))
      x <- c("next", "previous", "close")
    else
      x <- character(0)
  }

  if (length(x))
    x <- match.arg(x, c("next", "previous", "close"), several.ok = TRUE)

  # force array (not scalar) when serialised to JSON
  as.list(x)
}

# map a cicerone < 2.0.0 `position` to driver.js 1.x `side` + `align`
position_to_side_align <- function(position) {
  if (is.null(position)) return(list(side = NULL, align = NULL))

  # driver.js 1.x has no "over" side for a step with an element; centre the
  # popover on driver.js's default side instead
  if (position == "mid-center")
    return(list(side = NULL, align = "center"))

  parts <- strsplit(position, "-")[[1]]

  side <- parts[1]

  if (!side %in% c("left", "right", "top", "bottom")) {
    warning(
      "`position = \"", position,
      "\"` cannot be mapped to driver.js 1.x, ignoring",
      call. = FALSE
    )
    return(list(side = NULL, align = NULL))
  }

  align <- "start"
  if (length(parts) > 1) {
    align <- switch(
      parts[2],
      center = "center",
      bottom = "end",
      right = "end",
      "start"
    )
  }

  list(side = side, align = align)
}

# signal that an argument was removed or renamed in driver.js 1.x
deprecated_arg <- function(value, arg, replacement = NULL) {
  if (is.null(value)) return(invisible(NULL))

  msg <- sprintf(
    "`%s` is deprecated: driver.js 1.x no longer supports it, ignoring",
    arg
  )

  if (!is.null(replacement))
    msg <- sprintf("`%s` is deprecated, use `%s` instead", arg, replacement)

  warning(msg, call. = FALSE)
  invisible(NULL)
}

# build the driver.js 1.x config object shared by
# Cicerone$new() and initialise()
#
# --- WP4 begin: NULL defaults, shared with $set_config() ---
# Every formal below defaults to NULL, not driver.js's real default
# (TRUE/"close"/10/etc.). `Cicerone$new()`/`initialise()` always resolve
# and pass an explicit value for every one of these before calling
# build_config() (see their bodies), so this never changes what those two
# call sites send. `Cicerone$set_config()` is the reason for the change:
# it calls build_config() with only the arguments the caller supplied to
# `$set_config()`, relying on every *unsupplied* one defaulting to NULL so
# `drop_nulls()` below omits it from the outgoing message, instead of
# resending driver.js's default and clobbering whatever that key is
# currently live-set to.
# --- WP4 end ---
build_config <- function(
  animate = NULL,
  overlay_color = NULL,
  overlay_opacity = NULL,
  smooth_scroll = NULL,
  allow_close = NULL,
  allow_scroll = NULL,
  overlay_click_behavior = NULL,
  stage_padding = NULL,
  stage_radius = NULL,
  allow_keyboard_control = NULL,
  disable_active_interaction = NULL,
  advance_on_click = NULL,
  skip_missing_element = NULL,
  wait_for_element = NULL,
  popover_class = NULL,
  popover_offset = NULL,
  show_buttons = NULL,
  disable_buttons = NULL,
  show_progress = NULL,
  progress_text = NULL,
  progress_style = NULL,
  next_btn_text = NULL,
  prev_btn_text = NULL,
  done_btn_text = NULL,
  duration = NULL,
  on_popover_render = NULL,
  on_highlight_started = NULL,
  on_highlighted = NULL,
  on_deselected = NULL,
  on_destroy_started = NULL,
  on_destroyed = NULL,
  on_next_click = NULL,
  on_prev_click = NULL,
  on_close_click = NULL,
  on_done_click = NULL,
  # --- WP7 begin: exclusive / wait_for_visible ---
  exclusive = NULL,
  wait_for_visible = NULL
  # --- WP7 end ---
) {
  drop_nulls(list(
    animate = animate,
    overlayColor = overlay_color,
    overlayOpacity = overlay_opacity,
    smoothScroll = smooth_scroll,
    allowClose = allow_close,
    allowScroll = allow_scroll,
    overlayClickBehavior = overlay_click_behavior,
    stagePadding = stage_padding,
    stageRadius = stage_radius,
    allowKeyboardControl = allow_keyboard_control,
    disableActiveInteraction = disable_active_interaction,
    advanceOnClick = advance_on_click,
    skipMissingElement = skip_missing_element,
    waitForElement = wait_for_element,
    popoverClass = popover_class,
    popoverOffset = popover_offset,
    showButtons = normalize_buttons(show_buttons),
    disableButtons = normalize_buttons(disable_buttons),
    showProgress = show_progress,
    progressText = progress_text,
    # "text" is today's behaviour and is never sent, so a tour that never
    # touches `progress_style` gets a byte-identical config payload to
    # pre-2.1.0 cicerone
    progressStyle = if (!identical(progress_style, "text")) progress_style,
    nextBtnText = next_btn_text,
    prevBtnText = prev_btn_text,
    doneBtnText = done_btn_text,
    duration = duration,
    onPopoverRender = on_popover_render,
    onHighlightStarted = on_highlight_started,
    onHighlighted = on_highlighted,
    onDeselected = on_deselected,
    onDestroyStarted = on_destroy_started,
    onDestroyed = on_destroyed,
    onNextClick = on_next_click,
    onPrevClick = on_prev_click,
    onCloseClick = on_close_click,
    onDoneClick = on_done_click,
    # --- WP7 begin: exclusive / wait_for_visible ---
    # Not driver.js keys: read by cicerone's own `cicerone-start` handler
    # (srcjs/exts/tour.js), passed straight through `Driver(config)`'s
    # spread-into-defaults, which preserves unrecognised keys untouched
    # (verified in driver.js.mjs's `ne()`/`configure()`).
    exclusive = exclusive,
    waitForVisible = wait_for_visible
    # --- WP7 end ---
  ))
}

# build a driver.js 1.x popover object
build_popover <- function(
  title = NULL,
  description = NULL,
  side = NULL,
  align = NULL,
  position = NULL,
  popover_class = NULL,
  show_buttons = NULL,
  disable_buttons = NULL,
  show_progress = NULL,
  progress_text = NULL,
  progress_style = NULL,
  next_btn_text = NULL,
  prev_btn_text = NULL,
  done_btn_text = NULL,
  on_popover_render = NULL,
  on_next_click = NULL,
  on_prev_click = NULL,
  on_close_click = NULL,
  on_done_click = NULL
) {
  # backwards compatibility: position -> side + align
  if (!is.null(position) && is.null(side)) {
    mapped <- position_to_side_align(position)
    side <- mapped$side
    align <- align %||% mapped$align
  }

  drop_nulls(list(
    title = if (!is.null(title)) as.character(title),
    description = if (!is.null(description)) as.character(description),
    side = side,
    align = align,
    popoverClass = popover_class,
    showButtons = normalize_buttons(show_buttons),
    disableButtons = normalize_buttons(disable_buttons),
    showProgress = show_progress,
    progressText = progress_text,
    # unlike the config-level field, a step-level override is sent
    # verbatim (including "text"), since it is what tells JS to override
    # the tour's default for this one step rather than inherit it
    progressStyle = progress_style,
    nextBtnText = next_btn_text,
    prevBtnText = prev_btn_text,
    doneBtnText = done_btn_text,
    onPopoverRender = on_popover_render,
    onNextClick = on_next_click,
    onPrevClick = on_prev_click,
    onCloseClick = on_close_click,
    onDoneClick = on_done_click
  ))
}

# normalise step(advance_on=)/highlight(advance_on=) to the shape the JS
# side expects: {element, event}. Accepts a selector string (event
# defaults to "click"), or list(el = "...", event = "...").
normalize_advance_on <- function(x) {
  if (is.null(x)) return(NULL)

  if (is.character(x)) {
    assertthat::assert_that(
      assertthat::is.string(x),
      msg = "`advance_on` must be a single selector string"
    )
    x <- list(el = x)
  }

  assertthat::assert_that(
    is.list(x) && !is.null(x$el),
    msg = "`advance_on` must be a selector string, or list(el = ..., event = ...)"
  )
  assertthat::assert_that(
    assertthat::is.string(x$el),
    msg = "`advance_on`'s `el` must be a single character string"
  )

  event <- x$event %||% "click"
  assertthat::assert_that(
    assertthat::is.string(event),
    msg = "`advance_on`'s `event` must be a single character string"
  )

  list(element = prep_element(x$el), event = event)
}

# validate step(advance_when=)/highlight(advance_when=): a single string
# of JavaScript, or NULL. Passed through unchanged -- JS evaluates it.
validate_advance_when <- function(x) {
  if (!is.null(x)) {
    assertthat::assert_that(
      assertthat::is.string(x),
      msg = "`advance_when` must be a single character string of JavaScript"
    )
  }
  x
}

# --- WP4 begin: show_if ---
# validate step(show_if=): a single string of JavaScript, or NULL. Passed
# through unchanged -- JS evaluates it as `(step, opts) => boolean` against
# `allSteps[id]` on every `cicerone-start` (see srcjs/exts/tour.js).
validate_show_if <- function(x) {
  if (!is.null(x)) {
    assertthat::assert_that(
      assertthat::is.string(x),
      msg = "`show_if` must be a single character string of JavaScript"
    )
  }
  x
}
# --- WP4 end ---
