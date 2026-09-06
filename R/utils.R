generate_id <- function() {
  paste0(sample(letters, 26), collapse = "")
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
build_config <- function(
  animate = TRUE,
  overlay_color = NULL,
  overlay_opacity = .75,
  smooth_scroll = FALSE,
  allow_close = TRUE,
  allow_scroll = TRUE,
  overlay_click_behavior = "close",
  stage_padding = 10,
  stage_radius = NULL,
  allow_keyboard_control = TRUE,
  disable_active_interaction = FALSE,
  advance_on_click = NULL,
  skip_missing_element = NULL,
  wait_for_element = NULL,
  popover_class = NULL,
  popover_offset = NULL,
  show_buttons = TRUE,
  disable_buttons = NULL,
  show_progress = FALSE,
  progress_text = NULL,
  next_btn_text = "Next",
  prev_btn_text = "Previous",
  done_btn_text = "Done",
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
  on_done_click = NULL
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
    onDoneClick = on_done_click
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
