#' Define Hints
#'
#' Define hints: pulsing beacons attached to elements of the page that
#' open a popover when clicked. Powered by the driver.js 1.x hints
#' module.
#'
#' @section JavaScript callbacks:
#' All `on_*` arguments take a string of JavaScript defining a function.
#' Hint hooks receive `(element, hint, opts)` where `opts` contains
#' `config` and `hints`.
#'
#' @section Shiny events:
#' Cicerone hints fire the following Shiny inputs, where `id` is the id
#' of the `Hints` object: `{id}_cicerone_hint_opened`,
#' `{id}_cicerone_hint_dismissed`, and `{id}_cicerone_hint_button`.
#' Each carries a list with the hint's `id` and `element`.
#'
#' @seealso [cicerone_inputs]
#'
#' @export
Hints <- R6::R6Class(
  "Hints",
#' @details
#' Create a new `Hints` object.
#'
#' @param beacon_side Side of the element the beacon is placed on:
#' `"left"`, `"right"`, `"top"` or `"bottom"`.
#' @param beacon_align Alignment of the beacon along the chosen side:
#' `"start"`, `"center"` or `"end"`.
#' @param beacon_animate Whether the beacon pulses.
#' @param beacon_class Class added to the beacons, for custom styling.
#' @param button_text Text of the popover button.
#' @param popover_class Class added to hint popovers, for custom styling.
#' @param popover_offset Distance between the popover and the element,
#' in pixels.
#' @param overlay Whether to show an overlay when a hint is open.
#' @param overlay_color Color of the overlay, e.g.: `"#000"`.
#' @param overlay_opacity Opacity of the overlay, between 0 and 1.
#' @param on_open JavaScript function called when a hint is opened.
#' @param on_dismiss JavaScript function called when a hint is dismissed.
#' @param on_button_click JavaScript function called when a hint popover
#' button is clicked.
#' @param id A unique identifier, useful if you are using more than one
#' set of hints.
#'
#' @return A Hints object.
  public = list(
    initialize = function(
      beacon_side = NULL, beacon_align = NULL, beacon_animate = NULL,
      beacon_class = NULL, button_text = NULL, popover_class = NULL,
      popover_offset = NULL, overlay = NULL, overlay_color = NULL,
      overlay_opacity = NULL, on_open = NULL, on_dismiss = NULL,
      on_button_click = NULL, id = NULL
    ) {

      if(is.null(id))
        id <- generate_id()

      beacon <- drop_nulls(list(
        side = beacon_side,
        align = beacon_align,
        animate = beacon_animate,
        className = beacon_class
      ))

      config <- drop_nulls(list(
        buttonText = button_text,
        popoverClass = popover_class,
        popoverOffset = popover_offset,
        overlay = overlay,
        overlayColor = overlay_color,
        overlayOpacity = overlay_opacity,
        onOpen = on_open,
        onDismiss = on_dismiss,
        onButtonClick = on_button_click
      ))

      if(length(beacon))
        config$beacon <- beacon

      private$config <- config
      private$id <- id

      invisible(self)
    },
#' @details
#' Add a hint.
#'
#' @param el Selector of the element the hint is attached to, e.g.: an id.
#' @param title Title on the popover.
#' @param description Body of the popover.
#' @param side Side of the element the popover is positioned on.
#' @param align Alignment of the popover along the chosen side.
#' @param popover_class Class added to this hint's popover.
#' @param show_button Whether to show the popover button.
#' @param button_text Text of the popover button.
#' @param on_button_click JavaScript function called when the popover
#' button is clicked.
#' @param on_open JavaScript function called when this hint is opened.
#' @param on_dismiss JavaScript function called when this hint is
#' dismissed.
#' @param beacon_side Side of the element the beacon is placed on.
#' @param beacon_align Alignment of the beacon along the chosen side.
#' @param beacon_animate Whether the beacon pulses.
#' @param beacon_class Class added to this hint's beacon.
#' @param hint_id Identifier of the hint, used with the `open`,
#' `dismiss` and `restore` methods.
#' @param data A named list of arbitrary data attached to the hint,
#' available to JavaScript callbacks as `hint.data`.
    hint = function(el, title = NULL, description = NULL, side = NULL,
      align = NULL, popover_class = NULL, show_button = NULL,
      button_text = NULL, on_button_click = NULL, on_open = NULL,
      on_dismiss = NULL, beacon_side = NULL, beacon_align = NULL,
      beacon_animate = NULL, beacon_class = NULL, hint_id = NULL,
      data = NULL) {

      assertthat::assert_that(!missing(el), msg = "Must pass `el`")

      el <- prep_element(el)

      popover <- drop_nulls(list(
        title = if(!is.null(title)) as.character(title),
        description = if(!is.null(description)) as.character(description),
        side = side,
        align = align,
        popoverClass = popover_class,
        showButton = show_button,
        buttonText = button_text,
        onButtonClick = on_button_click
      ))

      beacon <- drop_nulls(list(
        side = beacon_side,
        align = beacon_align,
        animate = beacon_animate,
        className = beacon_class
      ))

      hint <- drop_nulls(list(
        element = el,
        id = hint_id,
        onOpen = on_open,
        onDismiss = on_dismiss,
        data = data
      ))

      if(length(popover)) hint$popover <- popover
      if(length(beacon)) hint$beacon <- beacon

      private$hints <- append(private$hints, list(hint))
      invisible(self)
    },
#' @details
#' Initialise the hints.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    init = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()

      opts <- list(
        config = private$config,
        hints = private$hints,
        id = private$id
      )

      session$sendCustomMessage("cicerone-hints-init", opts)
      invisible(self)
    },
#' @details
#' Show the hint beacons.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    show = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-hints-show", list(id = private$id))
      invisible(self)
    },
#' @details
#' Hide the hint beacons.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    hide = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-hints-hide", list(id = private$id))
      invisible(self)
    },
#' @details
#' Open a hint's popover.
#'
#' @param hint_id The identifier of the hint (see the `hint_id`
#' argument of the `hint` method) or its 1-based index.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    open = function(hint_id, session = NULL){
      assertthat::assert_that(!missing(hint_id), msg = "Must pass `hint_id`")
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      if(is.numeric(hint_id)) hint_id <- hint_id - 1
      session$sendCustomMessage(
        "cicerone-hints-open",
        list(id = private$id, hint = hint_id)
      )
      invisible(self)
    },
#' @details
#' Close the currently open hint popover.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    close = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-hints-close", list(id = private$id))
      invisible(self)
    },
#' @details
#' Dismiss a hint: hides its beacon until restored.
#'
#' @param hint_id The identifier of the hint or its 1-based index.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    dismiss = function(hint_id, session = NULL){
      assertthat::assert_that(!missing(hint_id), msg = "Must pass `hint_id`")
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      if(is.numeric(hint_id)) hint_id <- hint_id - 1
      session$sendCustomMessage(
        "cicerone-hints-dismiss",
        list(id = private$id, hint = hint_id)
      )
      invisible(self)
    },
#' @details
#' Restore a dismissed hint.
#'
#' @param hint_id The identifier of the hint or its 1-based index.
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    restore = function(hint_id, session = NULL){
      assertthat::assert_that(!missing(hint_id), msg = "Must pass `hint_id`")
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      if(is.numeric(hint_id)) hint_id <- hint_id - 1
      session$sendCustomMessage(
        "cicerone-hints-restore",
        list(id = private$id, hint = hint_id)
      )
      invisible(self)
    },
#' @details
#' Refresh beacon and popover positions.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
    refresh = function(session = NULL){
      if(is.null(session))
        session <- shiny::getDefaultReactiveDomain()
      session$sendCustomMessage("cicerone-hints-refresh", list(id = private$id))
      invisible(self)
    }
  ),
  private = list(
    hints = list(),
    config = list(),
    id = NULL
  )
)
