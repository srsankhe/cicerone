#' Shared parameter documentation
#'
#' Dummy topic holding `@param` documentation for arguments shared between
#' the functional API (`initialise()`/`highlight()`) and the equivalent
#' `Cicerone$new()`/`$step()` arguments, so the wording lives in one place
#' and cannot drift between the two APIs. Not a user-facing topic.
#'
#' @param allow_scroll Whether the page can be scrolled while a tour is
#' active, set to `FALSE` to lock body scroll.
#' @param disable_active_interaction Whether to disable interaction with
#' the highlighted element.
#' @param advance_on_click Whether clicking the highlighted element
#' advances the tour.
#' @param skip_missing_element Whether to skip steps whose element is
#' not found on the page.
#' @param wait_for_element Milliseconds to wait for a step's element to
#' appear before giving up.
#' @param disable_buttons Character vector of buttons to render disabled,
#' among `"next"`, `"previous"`, and `"close"`.
#' @param show_progress Whether to show tour progress text in the popover
#' (e.g.: `"2 of 5"`).
#' @param progress_text Template for the progress text, e.g.:
#' `"{{current}} of {{total}}"`.
#' @param duration Animation duration in milliseconds.
#' @param on_popover_render JavaScript function called when the popover
#' is rendered, receives `(popover, opts)`.
#' @param on_highlight_started,on_highlighted,on_deselected JavaScript
#' functions called around highlighting of every step.
#' @param on_destroy_started,on_destroyed JavaScript functions called
#' around tour destruction.
#' @param on_next_click,on_prev_click,on_close_click,on_done_click
#' JavaScript functions called on button clicks. When `on_next_click`
#' or `on_prev_click` is set, cicerone still fires the corresponding
#' Shiny event and advances the tour, unless the callback returns
#' `false`.
#' @param on_next A JavaScript function to run when the next button is
#' clicked. Unless the function returns `false` the tour then advances.
#' This is effectively a string that is evaluated JavaScript-side.
#' @param on_prev A JavaScript function to run when the previous button
#' is clicked. Unless the function returns `false` the tour then moves
#' back.
#' @param on_close A JavaScript function to run when the close button is
#' clicked.
#' @param on_done A JavaScript function to run when the done button is
#' clicked, on the last step.
#' @param advance_on Advance the tour when a DOM event fires on any
#' element on the page, not only the highlighted one (see
#' `advance_on_click` for that). A selector string (the event defaults
#' to `"click"`), or `list(el = "...", event = "...")`.
#' @param advance_when A JavaScript predicate `(step, opts) => boolean`.
#' Evaluated once when the step is highlighted, then again on every DOM
#' mutation and `input`/`change` event until it returns `true`, at which
#' point the tour advances. For a server-driven alternative, use
#' `observeEvent(input$x, tour$move_forward())`. On the tour's last step,
#' either mechanism ends the tour (there is no next step to move to);
#' `{id}_cicerone_ended$reason` is `"dismissed"` rather than `"done"` for
#' this, since it bypasses the Done button's hook resolution, the same
#' way `$move_forward()` does on the last step.
#' @param data A named list of arbitrary data attached to the step,
#' available to JavaScript callbacks as `step.data`.
#'
#' @name cicerone_params
#' @keywords internal
NULL
