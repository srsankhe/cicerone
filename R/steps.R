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
#' @seealso [cicerone_inputs], [tour_state()]
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
#' @param persist Where to persist this tour's progress across page
#' loads/reconnects: `NULL` (the default, no persistence), `"cookie"`
#' (cicerone manages a cookie for you), or `list(read = function(id),
#' write = function(id, record), forget = function(id))` to store the
#' record yourself (a session-scoped list, a database, ...). All three
#' functions are required. `persist` requires a stable, explicitly
#' passed `id` -- an auto-generated one is different every time and can
#' never be looked up again, so cicerone errors if you combine the two.
#' See the Persistence section below.
#' @param version An integer you control, bumped whenever a persisted
#' record from an earlier version of this tour should no longer count.
#' A stored record whose `v` does not match `version` reads as if there
#' were no record at all (cicerone does not migrate old records).
#'
#' @section Persistence:
#' With `persist` set, cicerone tracks one record per tour: `list(v,
#' status, idx, n, t)` -- `status` (`"in_progress"`, `"completed"`, or
#' `"dismissed"`), `idx` (the last 0-based step index shown), `n` (how
#' many times `$start()` has run), and `t` (an ISO-8601 UTC timestamp).
#' Reading and writing it drives three behaviours, for either backend:
#' * `{id}_cicerone_seen` fires once at `$init()`, with the record (or
#'   `NULL` if there is none) -- see [cicerone_inputs].
#' * `$init(run_once = TRUE)` also checks the record: if `status` is
#'   already `"completed"`, the next `$start()` does not drive the
#'   tour, and `{id}_cicerone_ended` fires with `reason = "suppressed"`
#'   instead.
#' * `$start(resume = TRUE)` begins at the record's `idx` instead of the
#'   requested `step`, when `status` is `"in_progress"` (i.e. the tour
#'   was dismissed partway through, not completed).
#'
#' `persist = "cookie"` needs nothing further: the browser cookie is
#' written and read by cicerone's own JavaScript. Read it server-side
#' with [tour_state()] (e.g. to decide what to render before the
#' `_seen` input arrives).
#'
#' A `list(read =, write =, forget =)` adapter instead stores the
#' record wherever you like; cicerone calls it, not a cookie. A minimal
#' adapter backed by `session$userData` (per-session only; use a
#' database or a keyed file for something that survives a full app
#' restart):
#' ```
#' userdata_adapter <- function(session) {
#'   list(
#'     read = function(id) session$userData$cicerone_tours[[id]],
#'     write = function(id, record) {
#'       if (is.null(session$userData$cicerone_tours))
#'         session$userData$cicerone_tours <- list()
#'       session$userData$cicerone_tours[[id]] <- record
#'     },
#'     forget = function(id) {
#'       session$userData$cicerone_tours[[id]] <- NULL
#'     }
#'   )
#' }
#'
#' tour <- Cicerone$new(id = "onboarding", persist = userdata_adapter(session))
#' ```
#' A database-backed adapter follows the same shape, keyed additionally
#' by user: `read <- function(id) db_get(user_id, id)`, `write <-
#' function(id, record) db_set(user_id, id, record)`, `forget <-
#' function(id) db_delete(user_id, id)`.
#'
#' `read()`/`write()`/`forget()` run in the calling session. An error
#' inside one is caught, reported with `warning()`, and does not stop
#' the tour.
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
      exclusive = TRUE, wait_for_visible = NULL,
      # --- WP5 begin: persistence ---
      persist = NULL, version = 1L
      # --- WP5 end ---
    ) {

      # --- WP5 begin: persistence validation ---
      # captured before `id` is possibly auto-generated below: persistence
      # needs a stable id across page loads/reconnects, an auto-generated
      # one is different every time and can never be looked up again
      auto_id <- is.null(id)

      assertthat::assert_that(persist_ok(persist))
      assertthat::assert_that(
        assertthat::is.count(version),
        msg = "`version` must be a single positive whole number"
      )
      # --- WP5 end ---

      if(is.null(id))
        id <- generate_id()

      # --- WP5 begin: persistence validation ---
      if(!is.null(persist) && auto_id)
        stop(
          "`persist` needs a stable `id`: pass `id = ` explicitly instead ",
          "of relying on an auto-generated one.",
          call. = FALSE
        )
      # --- WP5 end ---

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

      # --- WP5 begin: persistence ---
      private$persist <- persist
      private$persist_mode <- if(is.null(persist)) NULL else if(identical(persist, "cookie")) "cookie" else "adapter"
      private$version <- version
      # --- WP5 end ---

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

      private$run_once <- run_once

      # --- WP5 begin: read the adapter-backed record, wire up writes ---
      # the cookie backend needs none of this: its record lives in
      # document.cookie, read and written by persist.js, client-side
      record <- NULL
      if(identical(private$persist_mode, "adapter")) {
        record <- tryCatch(
          private$persist$read(private$id),
          error = function(e) {
            warning(
              "cicerone: persist$read() failed for '", private$id, "': ",
              conditionMessage(e), call. = FALSE
            )
            NULL
          }
        )
        if(!is.null(record) && !identical(record$v, private$version))
          record <- NULL

        private$persist_record <- record
        private$register_persist_observers(session)
      }
      # --- WP5 end ---

      opts <- list(
        globals = private$globals,
        steps = private$steps,
        id = private$id,
        # --- WP5 begin ---
        runOnce = run_once,
        persist = private$persist_mode,
        version = private$version
        # --- WP5 end ---
      )

      private$initialized <- TRUE
      session$sendCustomMessage("cicerone-init", opts)

      # --- WP5 begin: push the freshly-read adapter record to JS ---
      # so client-side run_once/resume decisions (and `_seen`) match what
      # was just read, without JS having to re-derive it
      if(identical(private$persist_mode, "adapter")) {
        session$sendCustomMessage(
          "cicerone-persist-record",
          list(id = private$id, record = record)
        )
      }
      # --- WP5 end ---

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
# --- WP5 begin: $forget() ---
#' @details
#' Forget this tour's persisted record (see the `persist` argument of
#' `$new()`). Removes it from the active backend (the cookie, or your
#' adapter's `forget(id)`) and fires `{id}_cicerone_seen` with `NULL`.
#' A no-op if `persist` was never set.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    forget = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      if(identical(private$persist_mode, "adapter")) {
        tryCatch(
          private$persist$forget(private$id),
          error = function(e) warning(
            "cicerone: persist$forget() failed for '", private$id, "': ",
            conditionMessage(e), call. = FALSE
          )
        )
      }

      private$persist_record <- NULL
      session$sendCustomMessage("cicerone-forget", list(id = private$id))
      invisible(self)
    },
# --- WP5 end ---
#' @details
#' Start Cicerone.
#'
#' @param step The step index at which to start.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
#' @param resume When persistence is on (see the `persist` argument of
#' `$new()`) and the persisted record's `status` is `"in_progress"`,
#' start at its `idx` instead of `step`. Ignored otherwise (including
#' when there is no persisted record, or its `status` is `"completed"`
#' or `"dismissed"`).
    start = function(step = 1, session = NULL, resume = FALSE){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      # we run it once and it already did
      if(private$run_once && private$runs > 0L)
        return(invisible(self))

      private$runs <- private$runs + 1L
      step <- step - 1
      session$sendCustomMessage(
        "cicerone-start",
        list(step = step, id = private$id, resume = isTRUE(resume))
      )

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
#' `"superseded"`, `"suppressed"`, `"dismissed"`), `completed` (`TRUE`
#' when `reason` is `"done"`), `index` and `total_steps`. See
#' [cicerone_inputs].
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
    initialized = FALSE,
    # --- WP4 end ---
    # --- WP5 begin: persistence ---
    persist = NULL,
    persist_mode = NULL,
    version = 1L,
    persist_record = NULL,
    # Adapter backend only (cookie backend's writes are entirely
    # client-side, see srcjs/exts/persist.js): build a record from each
    # of `_started`/`_state`/`_ended` and call `persist$write(id,
    # record)`. `_started`/`_state`/`_ended` are the existing bridge
    # inputs (see `?cicerone_inputs`); persistence adds no new ones on
    # the write side.
    #
    # `persist_on_started`/`persist_on_state`/`persist_on_ended` are
    # deliberately plain, directly-callable methods (not inlined into
    # the `observeEvent()` calls below) so tests can invoke them with a
    # hand-built payload and no reactive context at all -- see
    # test-persist.R.
    write_persist_record = function(record) {
      id <- private$id
      tryCatch(
        private$persist$write(id, record),
        error = function(e) warning(
          "cicerone: persist$write() failed for '", id, "': ",
          conditionMessage(e), call. = FALSE
        )
      )
    },
    persist_on_started = function(payload) {
      prev <- private$persist_record
      record <- list(
        v = private$version,
        status = "in_progress",
        idx = payload$index,
        n = (if(!is.null(prev)) prev$n else 0L) + 1L,
        t = iso_now()
      )
      private$persist_record <- record
      private$write_persist_record(record)
    },
    persist_on_state = function(payload) {
      # `_state` and `_started` are both emitted from the same
      # onHighlighted call (bridge.js emits `_state` first, then
      # `_started` when `!active[id]`), as two separate Shiny inputs;
      # Shiny does not guarantee which of the two observers below runs
      # first within the resulting flush. `n`'s fallback must therefore
      # be 0, not 1 -- matching `persist_on_started`'s own "no prior
      # record" fallback -- so the final count is 1 regardless of
      # which handler happens to run first (0 -> `_started` bumps to 1,
      # or `_started` already set 1 and this leaves it alone).
      prev <- private$persist_record
      record <- list(
        v = private$version,
        status = if(!is.null(prev)) prev$status else "in_progress",
        idx = payload$index,
        n = if(!is.null(prev)) prev$n else 0L,
        t = iso_now()
      )
      private$persist_record <- record
      private$write_persist_record(record)
    },
    persist_on_ended = function(payload) {
      # a suppressed start never actually ran: nothing changed, the
      # existing record already reflects the last real outcome
      if(identical(payload$reason, "suppressed")) return(invisible(NULL))

      prev <- private$persist_record
      record <- list(
        v = private$version,
        status = if(identical(payload$reason, "done")) "completed" else "dismissed",
        idx = if(!is.null(payload$index)) payload$index else if(!is.null(prev)) prev$idx else NULL,
        n = if(!is.null(prev)) prev$n else 1L,
        t = iso_now()
      )
      private$persist_record <- record
      private$write_persist_record(record)
    },
    register_persist_observers = function(session) {
      id <- private$id

      shiny::observeEvent(
        session$input[[paste0(id, "_cicerone_started")]],
        private$persist_on_started(session$input[[paste0(id, "_cicerone_started")]]),
        ignoreInit = TRUE, domain = session
      )

      shiny::observeEvent(
        session$input[[paste0(id, "_cicerone_state")]],
        private$persist_on_state(session$input[[paste0(id, "_cicerone_state")]]),
        ignoreInit = TRUE, domain = session
      )

      shiny::observeEvent(
        session$input[[paste0(id, "_cicerone_ended")]],
        private$persist_on_ended(session$input[[paste0(id, "_cicerone_ended")]]),
        ignoreInit = TRUE, domain = session
      )
    }
    # --- WP5 end ---
  )
)
