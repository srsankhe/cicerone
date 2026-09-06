#' Define Steps
#'
#' Define cicerone steps, powered by driver.js 1.x.
#'
#' @section Side and alignment:
#' driver.js 1.x positions popovers with `side` (`left`, `right`,
#' `top`, `bottom`) and `align` (`start`, `center`, `end`). For a
#' centred popover with no target element, omit `el`; driver.js
#' renders it over the page.
#' The pre-2.0.0 `position` argument is still accepted and mapped to
#' the equivalent `side`/`align` pair:
#' * `left`, `right`, `top`, `bottom`
#' * `left-center`, `left-bottom`
#' * `top-center`, `top-right`
#' * `right-center`, `right-bottom`
#' * `bottom-center`
#' * `mid-center` (no 1.x equivalent for a step with an element: maps to
#'   `align = "center"` on driver.js's default side)
#'
#' @section JavaScript callbacks:
#' All `on_*` arguments take a string of JavaScript defining a function.
#' Tour hooks receive `(element, step, opts)` where `opts` contains
#' `config`, `state`, `driver` and `index` (the active step's 0-based
#' index, possibly `undefined`). For example:
#' `"function(element, step, opts) { console.log(step); }"`.
#'
#' @seealso [cicerone_inputs]
#'
#' @export
Cicerone <- R6::R6Class(
  "Cicerone",
#' @details
#' Create a new `Cicerone` object.
#'
#' @param animate Whether to animate or not.
#' @param opacity Deprecated, use `overlay_opacity`. Background opacity
#' (0 means only popovers and without overlay).
#' @param padding Deprecated, use `stage_padding`. Distance of element
#' from around the edges.
#' @param allow_close Whether clicking on the overlay should close the tour.
#' @param overlay_click_next Deprecated, use `overlay_click_behavior`.
#' Whether the click on overlay should move next.
#' @param done_btn_text Text on the final button.
#' @param close_btn_text Deprecated: driver.js 1.x renders the close
#' button as an x icon, it no longer has text.
#' @param stage_background Deprecated: driver.js 1.x cuts the highlighted
#' element out of an SVG overlay, there is no stage element to color.
#' @param next_btn_text Next button text.
#' @param prev_btn_text Previous button text.
#' @param show_btns Whether to show control buttons in the footer. Either
#' `TRUE`/`FALSE`, or a character vector of buttons to show among
#' `"next"`, `"previous"`, and `"close"`.
#' @param keyboard_control Allow controlling through keyboard (escape
#' to close, arrow keys to move).
#' @param id A unique identifier, useful if you are using more than one
#' cicerone.
#' @param mathjax Whether to use MathJax in the steps.
#' @param overlay_color Color of the page overlay, e.g.: `"#000"`.
#' @param overlay_opacity Opacity of the page overlay, between 0 and 1.
#' @param overlay_click_behavior What clicking the overlay does: `"close"`
#' (default) closes the tour, `"nextStep"` moves to the next step, or a
#' string of JavaScript defining a custom handler.
#' @param smooth_scroll Whether to smooth scroll to the highlighted element.
#' @param allow_scroll Whether the page can be scrolled while a tour is
#' active, set to `FALSE` to lock body scroll.
#' @param stage_padding Distance between the highlighted element and the
#' edge of the cutout, in pixels.
#' @param stage_radius Corner radius of the cutout around the highlighted
#' element, in pixels.
#' @param disable_active_interaction Whether to disable interaction with
#' the highlighted element.
#' @param advance_on_click Whether clicking the highlighted element
#' advances the tour.
#' @param skip_missing_element Whether to skip steps whose element is
#' not found on the page.
#' @param wait_for_element Milliseconds to wait for a step's element to
#' appear before giving up.
#' @param popover_class Class added to all popovers, for custom styling.
#' @param popover_offset Distance between the popover and the highlighted
#' element, in pixels.
#' @param disable_buttons Character vector of buttons to render disabled,
#' among `"next"`, `"previous"`, and `"close"`.
#' @param show_progress Whether to show tour progress text in the popover
#' (e.g.: `"2 of 5"`).
#' @param progress_text Template for the progress text, e.g.:
#' `"{{current}} of {{total}}"`.
#' @param progress_style Progress indicator style: `"text"` (the
#' default, e.g.: `"2 of 5"`), `"bar"`, or `"dots"`, themable with
#' [cicerone_theme()]. `"bar"`/`"dots"` force `show_progress` on
#' regardless of the `show_progress` argument.
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
#' @param exclusive Whether starting this tour first destroys every other
#' currently active [Cicerone] tour (their `_ended` reason is
#' `"superseded"`), so only one tour is ever visible at a time. Defaults
#' to `TRUE`. Set to `FALSE` to allow overlapping tours; driver.js gives
#' each tour its own popover and overlay, so two active tours mean two
#' `.driver-popover` elements on the page at once (and, upstream, a
#' duplicate `driver-popover-content` id). Hints are unaffected: they are
#' not tours. See [destroy_all()] for a session-wide teardown regardless
#' of `exclusive`.
#' @param wait_for_visible Milliseconds to wait, before starting or
#' moving to a step, for that step's element to not just exist but have
#' a non-zero size (`getBoundingClientRect()` width and height both
#' greater than 0) -- e.g. an element inside a Shiny tab that has not
#' been shown yet, or one behind a slow render. Unlike `wait_for_element`
#' (which only checks existence, and is implemented by driver.js itself),
#' this is implemented by cicerone and only gates moves cicerone itself
#' makes (`$start()`, the Next/Previous buttons, `on_next`/`on_prev`
#' hooks that do not return `false`); a move made directly through
#' `window.cicerone.drivers` bypasses it. On timeout, cicerone emits
#' `{id}_cicerone_event` with `type = "anchor_timeout"` and moves anyway,
#' unless `skip_missing_element` applies to that step, in which case it
#' is skipped. Also settable per step, see the `wait_for_visible`
#' argument of `step()` below, which overrides this default.
#'
#' @return A Cicerone object.
  public = list(
    initialize = function(
      animate = TRUE, opacity = NULL, padding = NULL,
      allow_close = TRUE, overlay_click_next = NULL, done_btn_text = "Done",
      close_btn_text = NULL, stage_background = NULL, next_btn_text = "Next",
      prev_btn_text = "Previous", show_btns = TRUE, keyboard_control = TRUE,
      id = NULL, mathjax = FALSE,
      overlay_color = NULL, overlay_opacity = .75,
      overlay_click_behavior = NULL, smooth_scroll = FALSE,
      allow_scroll = TRUE,
      stage_padding = 10, stage_radius = NULL,
      disable_active_interaction = FALSE, advance_on_click = NULL,
      skip_missing_element = NULL, wait_for_element = NULL,
      popover_class = NULL, popover_offset = NULL,
      disable_buttons = NULL, show_progress = FALSE, progress_text = NULL,
      progress_style = c("text", "bar", "dots"),
      duration = NULL,
      on_popover_render = NULL,
      on_highlight_started = NULL, on_highlighted = NULL,
      on_deselected = NULL,
      on_destroy_started = NULL, on_destroyed = NULL,
      on_next_click = NULL, on_prev_click = NULL,
      on_close_click = NULL, on_done_click = NULL,
      exclusive = TRUE, wait_for_visible = NULL
    ) {

      if(is.null(id))
        id <- generate_id()

      # deprecated arguments removed from driver.js 1.x
      deprecated_arg(close_btn_text, "close_btn_text")
      deprecated_arg(stage_background, "stage_background")

      # deprecated arguments mapped to their driver.js 1.x equivalent
      overlay_opacity <- opacity %||% overlay_opacity
      stage_padding <- padding %||% stage_padding

      if(is.null(overlay_click_behavior)) {
        overlay_click_behavior <- "close"
        if(isTRUE(overlay_click_next))
          overlay_click_behavior <- "nextStep"
      }

      progress_style <- match.arg(progress_style, progress_styles)
      show_progress <- resolve_show_progress(progress_style, show_progress)

      private$globals <- build_config(
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
        progress_style = progress_style,
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
        on_done_click = on_done_click,
        exclusive = exclusive,
        wait_for_visible = wait_for_visible
      )

      private$globals$id <- id
      private$id <- id
      private$mathjax <- mathjax

      invisible(self)
    },
#' @details
#' Add a step.
#'
#' @param el Selector of the element to highlight, e.g.: an id or a class.
#' Use `NULL` together with `title`/`description` for a modal-like step
#' with no highlighted element.
#' @param title Title on the popover.
#' @param description Body of the popover.
#' @param position Deprecated, use `side` and `align`. See the side and
#' alignment section.
#' @param side Side the popover is positioned on: `"left"`, `"right"`,
#' `"top"` or `"bottom"`. For a centred popover with no target
#' element, omit `el`; driver.js renders it over the page.
#' @param align Alignment of the popover along the chosen side:
#' `"start"`, `"center"` or `"end"`.
#' @param class className for this specific step's popover, in
#' addition to the general `popover_class` of the tour.
#' @param show_btns Buttons to show for this step, `TRUE`/`FALSE` or a
#' character vector among `"next"`, `"previous"`, and `"close"`.
#' @param disable_buttons Buttons to render disabled for this step.
#' @param close_btn_text Deprecated: driver.js 1.x renders the close
#' button as an x icon, it no longer has text.
#' @param next_btn_text Next button text for this step.
#' @param prev_btn_text Previous button text for this step.
#' @param done_btn_text Done button text, on the last step.
#' @param show_progress Whether to show progress text on this step.
#' @param progress_text Progress text template for this step, e.g.:
#' `"{{current}} of {{total}}"`.
#' @param progress_style Progress indicator style for this step:
#' `"text"`, `"bar"`, or `"dots"`. `NULL` (the default) inherits the
#' tour's style; `"bar"`/`"dots"` force `show_progress` on for this step
#' regardless of the `show_progress` argument.
#' @param tab_id The id of the tabs to activate in order to highlight `tab_id`.
#' @param is_id **Deprecated** Whether the selector passed to `el` is an
#' HTML id, other selectors are detected automatically.
#' @param tab The name of the tab to set.
#' @param on_highlighted A JavaScript function to run when the step is
#' highlighted, generally a callback function. This is effectively a
#' string that is evaluated JavaScript-side.
#' @param on_highlight_started A JavaScript function to run when the step
#' is just about to be highlighted, generally a callback function. This is
#' effectively a string that is evaluated JavaScript-side.
#' @param on_deselected A JavaScript function to run when the step is
#' deselected (the tour moved away from it).
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
#' @param on_popover_render A JavaScript function to run when this step's
#' popover is rendered.
#' @param disable_active_interaction Whether to disable interaction with
#' the highlighted element for this step.
#' @param advance_on_click Whether clicking the highlighted element
#' advances the tour, for this step.
#' @param skip_missing_element Whether to skip this step if its element
#' is not found.
#' @param wait_for_element Milliseconds to wait for this step's element
#' to appear before giving up.
#' @param advance_on Advance the tour when a DOM event fires on any
#' element on the page, not only the highlighted one (see
#' `advance_on_click` for that). A selector string (the event defaults
#' to `"click"`), or `list(el = "...", event = "...")`.
#' @param advance_when A JavaScript predicate `(step, opts) => boolean`.
#' Evaluated once when the step is highlighted, then again on every DOM
#' mutation and `input`/`change` event until it returns `true`, at which
#' point the tour advances. For a server-driven alternative, use
#' `observeEvent(input$x, tour$move_forward())`. On the last step, either
#' mechanism completes the tour (`_ended$reason = "done"`), as does
#' `$move_forward()`.
#' @param wait_for_visible Milliseconds to wait for this step's element to
#' not just exist but have a non-zero size, before moving to it. Overrides
#' the tour-level `wait_for_visible` (`Cicerone$new(wait_for_visible = )`)
#' for this step only; see there for the full behaviour.
#' @param show_if A JavaScript predicate `(step, opts) => boolean`,
#' evaluated for every step when the tour is `$start()`-ed. A step whose
#' predicate returns `false` is skipped for that run: it does not count
#' towards `total_steps` and is not highlighted. Predicates are
#' re-evaluated on every `$start()` (not once at `$init()`), so a
#' predicate that reads live DOM/input state (e.g.
#' `"(step, opts) => document.querySelector('#x').checked"`) can show a
#' different set of steps on different runs. A predicate that throws is
#' treated as `true` (the step is shown) and logged with `console.warn`.
#' If `$start(step = )` requests a step that `show_if` removes, the tour
#' starts at the next visible step after it instead; if none of the
#' steps from that point on are visible, the tour does not start and
#' `{id}_cicerone_event` fires once with `type = "no_visible_steps"` (see
#' `?cicerone_inputs`).
#' @param data A named list of arbitrary data attached to the step,
#' available to JavaScript callbacks as `step.data`.
    step = function(el = NULL, title = NULL, description = NULL, position = NULL,
      class = NULL, show_btns = NULL, close_btn_text = NULL,
      next_btn_text = NULL, prev_btn_text = NULL, tab = NULL, tab_id = NULL,
      is_id = NULL,
      on_highlighted = NULL, on_highlight_started = NULL, on_next = NULL,
      side = NULL, align = NULL,
      disable_buttons = NULL, show_progress = NULL, progress_text = NULL,
      progress_style = NULL,
      done_btn_text = NULL,
      on_deselected = NULL, on_prev = NULL, on_close = NULL, on_done = NULL,
      on_popover_render = NULL,
      disable_active_interaction = NULL, advance_on_click = NULL,
      skip_missing_element = NULL, wait_for_element = NULL,
      advance_on = NULL, advance_when = NULL, wait_for_visible = NULL,
      show_if = NULL,
      data = NULL) {

      if(!is.null(is_id))
        .Deprecated(
          msg = "`is_id` is deprecated, selectors are detected automatically"
        )

      deprecated_arg(close_btn_text, "close_btn_text")

      assertthat::assert_that(
        !is.null(el) || !is.null(title) || !is.null(description),
        msg = "Must pass `el`, or `title`/`description` for an element-less step"
      )

      assertthat::assert_that(tabs_ok(tab, tab_id))

      if(!is.null(el))
        el <- prep_element(el)

      if(!is.null(progress_style))
        progress_style <- match.arg(progress_style, progress_styles)
      show_progress <- resolve_show_progress(progress_style, show_progress)

      if(private$mathjax) {
        on_highlighted <- paste0(
          "function(element, step, opts){setTimeout(function(){
          MathJax.Hub.Queue(['Typeset', MathJax.Hub]);
        }, 300);", on_highlighted, "}"
        )
      }

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
        progress_style = progress_style,
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
        tab_id = tab_id,
        tab = tab,
        onHighlighted = on_highlighted,
        onHighlightStarted = on_highlight_started,
        onDeselected = on_deselected,
        disableActiveInteraction = disable_active_interaction,
        advanceOnClick = advance_on_click,
        skipMissingElement = skip_missing_element,
        waitForElement = wait_for_element,
        advanceOn = normalize_advance_on(advance_on),
        advanceWhen = validate_advance_when(advance_when),
        waitForVisible = wait_for_visible,
        showIf = validate_show_if(show_if),
        data = data
      ))

      if(length(popover)) step$popover <- popover

      private$steps <- append(private$steps, list(step))
      invisible(self)
    },
#' @details
#' Initialise Cicerone.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
#' @param run_once Whether to only run the guide once. If `TRUE`
#' any subsequent calls of the method will not run the guide.
    init = function(session = NULL, run_once = FALSE){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      opts <- list(
        globals = private$globals,
        steps = private$steps,
        id = private$id
      )

      private$run_once <- run_once
      private$initialized <- TRUE
      session$sendCustomMessage("cicerone-init", opts)
      invisible(self)
    },
#' @details
#' Reset (destroy) Cicerone: exits the tour and removes the overlay.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    reset = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-reset", list(id = private$id))
      invisible(self)
    },
#' @details
#' Alias for `reset`, matching driver.js 1.x terminology.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    destroy = function(session = NULL){
      self$reset(session)
    },
#' @details
#' Start Cicerone.
#'
#' @param step The step index at which to start.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    start = function(step = 1, session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      # we run it once and it already did
      if(private$run_once && private$runs > 0L)
        return(invisible(self))

      private$runs <- private$runs + 1L
      step <- step - 1
      session$sendCustomMessage("cicerone-start", list(step = step, id = private$id))

      invisible(self)
    },
#' @details
#' Move Cicerone one step.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    move_forward = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-next", list(id = private$id))
      invisible(self)
    },
#' @details
#' Move Cicerone one step backward.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    move_backward = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-previous", list(id = private$id))
      invisible(self)
    },
#' @details
#' Move Cicerone to a specific step.
#'
#' @param step The step index to move to.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    move_to = function(step, session = NULL){
      assertthat::assert_that(!missing(step), msg = "Must pass `step`.")
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage(
        "cicerone-move-to",
        list(step = step - 1, id = private$id)
      )
      invisible(self)
    },
#' @details
#' Refresh the overlay and popover positions, e.g.: after
#' dynamically resizing an element.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    refresh = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-refresh", list(id = private$id))
      invisible(self)
    },
#' @details
#' Highlight a specific element.
#'
#' @param el Selector of the element to highlight.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    highlight = function(el, session = NULL){
      assertthat::assert_that(!missing(el), msg = "Must pass `el`.")
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      el <- prep_element(el)

      session$sendCustomMessage("cicerone-highlight", list(el = el, id = private$id))
      invisible(self)
    },
#' @details
#' Retrieve the id of the currently highlighted element.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_highlighted_el = function(session = NULL){
      .Deprecated("get_state", package = "cicerone")
      state <- self$get_state(session)
      if(is.null(state))
        return(invisible(NULL))
      state$highlighted
    },
#' @details
#' Retrieve the id of the previously highlighted element.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_previous_el = function(session = NULL){
      .Deprecated("get_state", package = "cicerone")
      state <- self$get_state(session)
      if(is.null(state))
        return(invisible(NULL))
      state$before_previous
    },
#' @details
#' Retrieve whether there is a next step.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    has_next_step = function(session = NULL){
      .Deprecated("get_state", package = "cicerone")
      state <- self$get_state(session)
      if(is.null(state))
        return(invisible(NULL))
      state$has_next
    },
#' @details Retrieve the state of the tour: a list with `highlighted`
#' (the highlighted element's id), `previous` (**deprecated**: this
#' duplicates `highlighted`, not the previously highlighted element;
#' kept only for cicerone < 2.0.0 compatibility, use `before_previous`
#' instead), `before_previous` (the previously highlighted element's
#' id), `has_next`, `has_previous`, `index` (0-based active step
#' index), `is_first`, `is_last`, and `total_steps`. Updated every
#' time a step is highlighted.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_state = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      grab <- paste0(private$id, "_cicerone_state")
      session$input[[grab]]
    },
#' @details Retrieve data that was fired when the user hit the "next" button.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_next = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      grab <- paste0(private$id, "_cicerone_next")
      session$input[[grab]]
    },
#' @details Retrieve data that was fired when the user hit the "previous" button.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_previous = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      grab <- paste0(private$id, "_cicerone_previous")
      session$input[[grab]]
    },
#' @details Retrieve data that was fired the first time a step was
#' highlighted after `$start()`: a list with `index` (0-based) and
#' `total_steps`. Fires once per `$start()`; a subsequent `$move_to()`
#' does not re-fire it. See [cicerone_inputs].
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_started = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      grab <- paste0(private$id, "_cicerone_started")
      session$input[[grab]]
    },
#' @details Retrieve data that was fired when the tour ended: a list
#' with `reason` (one of `"done"`, `"close"`, `"programmatic"`,
#' `"dismissed"`), `completed` (`TRUE` when `reason` is `"done"`),
#' `index` and `total_steps`. See [cicerone_inputs].
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    get_ended = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      grab <- paste0(private$id, "_cicerone_ended")
      session$input[[grab]]
    },
#' @details
#' Retrieve this tour's unique identifier.
    get_id = function(){
      private$id
    },
#' @details
#' Retrieve the list of steps as they will be sent to driver.js.
    get_steps = function(){
      private$steps
    },
# --- WP4 begin: mutable tours ---
#' @details
#' Send the current list of steps (built by `$step()`) to the browser
#' and replace whatever steps the live tour is driving. Typically
#' paired with `$clear_steps()`:
#' `tour$clear_steps()$step(...)$step(...)$set_steps()`. Best called
#' between tours (before `$start()`), not while one is active: driver.js
#' resets its live position when steps are replaced. Requires `$init()`
#' to have already been called -- there is no live tour to update
#' otherwise.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    set_steps = function(session = NULL){
      if(!private$initialized)
        stop(
          "`$set_steps()` requires `$init()` to have been called first",
          call. = FALSE
        )

      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      session$sendCustomMessage(
        "cicerone-set-steps",
        list(id = private$id, steps = private$steps)
      )
      invisible(self)
    },
#' @details
#' Empty this tour's list of steps, so subsequent `$step()` calls start
#' a fresh list. Only changes what `$set_steps()`/`$init()` will send
#' next; the live browser-side tour, if any, is untouched until one of
#' those is also called. Chainable, see `$set_steps()`.
    clear_steps = function(){
      private$steps <- list()
      invisible(self)
    },
#' @details
#' Update this tour's configuration after `$init()`, without rebuilding
#' the tour. Accepts the same named arguments as `$new()` (minus `id`,
#' `mathjax`, and the deprecated pre-2.0.0 aliases); only the arguments
#' you actually pass are sent, and only those are changed -- anything
#' you leave as `NULL` (the default for every argument here, unlike
#' `$new()`) is left exactly as it already is. Steps are unaffected; use
#' `$set_steps()` for those.
#'
#' @param animate Whether to animate or not.
#' @param allow_close Whether clicking on the overlay should close the tour.
#' @param overlay_color Color of the page overlay, e.g.: `"#000"`.
#' @param overlay_opacity Opacity of the page overlay, between 0 and 1.
#' @param overlay_click_behavior What clicking the overlay does: `"close"`,
#' `"nextStep"`, or a string of JavaScript defining a custom handler.
#' @param smooth_scroll Whether to smooth scroll to the highlighted element.
#' @param allow_scroll Whether the page can be scrolled while a tour is
#' active, set to `FALSE` to lock body scroll.
#' @param stage_padding Distance between the highlighted element and the
#' edge of the cutout, in pixels.
#' @param stage_radius Corner radius of the cutout around the highlighted
#' element, in pixels.
#' @param keyboard_control Allow controlling through keyboard (escape
#' to close, arrow keys to move).
#' @param popover_class Class added to all popovers, for custom styling.
#' @param popover_offset Distance between the popover and the highlighted
#' element, in pixels.
#' @param show_btns Whether to show control buttons in the footer. Either
#' `TRUE`/`FALSE`, or a character vector of buttons to show among
#' `"next"`, `"previous"`, and `"close"`.
#' @param next_btn_text Next button text.
#' @param prev_btn_text Previous button text.
#' @param done_btn_text Text on the final button.
#' @param exclusive Whether starting this tour first destroys every other
#' currently active [Cicerone] tour. See `$new()`.
#' @param wait_for_visible Milliseconds to wait, before starting or
#' moving to a step, for that step's element to have a non-zero size.
#' See `$new()`.
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
#' @param progress_style Progress indicator style: `"text"` (the
#' default, e.g.: `"2 of 5"`), `"bar"`, or `"dots"`, themable with
#' [cicerone_theme()]. `"bar"`/`"dots"` force `show_progress` on
#' regardless of the `show_progress` argument.
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
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    set_config = function(
      animate = NULL, overlay_color = NULL, overlay_opacity = NULL,
      allow_close = NULL, overlay_click_behavior = NULL,
      smooth_scroll = NULL, allow_scroll = NULL,
      stage_padding = NULL, stage_radius = NULL,
      keyboard_control = NULL,
      disable_active_interaction = NULL, advance_on_click = NULL,
      skip_missing_element = NULL, wait_for_element = NULL,
      popover_class = NULL, popover_offset = NULL,
      show_btns = NULL, disable_buttons = NULL,
      show_progress = NULL, progress_text = NULL, progress_style = NULL,
      next_btn_text = NULL, prev_btn_text = NULL, done_btn_text = NULL,
      duration = NULL,
      on_popover_render = NULL,
      on_highlight_started = NULL, on_highlighted = NULL,
      on_deselected = NULL,
      on_destroy_started = NULL, on_destroyed = NULL,
      on_next_click = NULL, on_prev_click = NULL,
      on_close_click = NULL, on_done_click = NULL,
      exclusive = NULL, wait_for_visible = NULL,
      session = NULL
    ){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      if(!is.null(progress_style))
        progress_style <- match.arg(progress_style, progress_styles)
      show_progress <- resolve_show_progress(progress_style, show_progress)

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
        progress_style = progress_style,
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
        on_done_click = on_done_click,
        exclusive = exclusive,
        wait_for_visible = wait_for_visible
      )

      session$sendCustomMessage(
        "cicerone-set-config",
        list(id = private$id, globals = globals)
      )
      invisible(self)
    }
# --- WP4 end ---
  ),
  private = list(
    steps = list(),
    globals = list(),
    id = NULL,
    runs = 0L,
    run_once = FALSE,
    mathjax = FALSE,
    # --- WP4 begin ---
    initialized = FALSE
    # --- WP4 end ---
  )
)
