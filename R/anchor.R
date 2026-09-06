#' Destroy every active tour
#'
#' Destroys every currently active [Cicerone] tour on the page, regardless
#' of `id`. Unlike a single tour's `$reset()`/`$destroy()`, this is not
#' scoped to one tour: use it as a single, session-wide teardown, e.g.
#' before navigating to a new page section or starting an unrelated flow.
#' Every affected tour's `_ended` input fires with `reason =
#' "programmatic"` (see [cicerone_inputs]). Hints are not affected -- they
#' are not tours.
#'
#' @param session A valid Shiny session if `NULL` the function attempts to
#' get the session with [shiny::getDefaultReactiveDomain()].
#'
#' @return Invisibly, the session.
#'
#' @seealso [Cicerone], [cicerone_inputs]
#' @export
destroy_all <- function(session = NULL) {
  if (is.null(session))
    session <- shiny::getDefaultReactiveDomain()

  session$sendCustomMessage("cicerone-destroy-all", list())
  invisible(session)
}

#' Wait for an element to appear (and become visible) in the DOM
#'
#' Resolves as soon as `selector` matches an element on the page, without
#' needing a [Cicerone] tour or [Hints]. Use it to gate a `$start()` call,
#' or any other server-side logic, on a piece of UI that renders
#' asynchronously: an `insertUI()`, a slow render, an element inside a
#' hidden tab.
#'
#' The result arrives on the `{id}_cicerone_anchor` Shiny input (event
#' priority), a list with `selector`, `found`, `visible` and `elapsed`
#' (milliseconds). `found` is `TRUE` once `selector` matches an element;
#' `visible` is `TRUE` once that element's `getBoundingClientRect()` has
#' both width and height greater than 0. If `timeout` elapses first,
#' `found`/`visible` report whatever was true at that point (both `FALSE`
#' if the selector never matched at all).
#'
#' @param selector A CSS selector, e.g.: `"#my_div"` or `".my-class"`.
#' @param timeout Milliseconds to wait before giving up.
#' @param visible Whether the element must also have a non-zero size, not
#' just exist in the DOM. `FALSE` only checks existence -- useful for an
#' element inside a hidden tab, which exists but has no size until the
#' tab is shown.
#' @param id Identifier of the `{id}_cicerone_anchor` input the result is
#' sent to. Defaults to a sanitised form of `selector`
#' (`gsub("[^A-Za-z0-9]", "_", selector)`), so a call with no explicit
#' `id` can be observed with, e.g., for `selector = "#late"`:
#' `observeEvent(input$late_cicerone_anchor, ...)`.
#' @param session A valid Shiny session if `NULL` the function attempts to
#' get the session with [shiny::getDefaultReactiveDomain()].
#'
#' @return Invisibly, the `id` the result will arrive under (i.e. the
#' input to observe is `paste0(id, "_cicerone_anchor")`).
#'
#' @seealso [cicerone_inputs]
#' @export
wait_for_element <- function(selector, timeout = 5000, visible = TRUE,
  id = NULL, session = NULL) {

  assertthat::assert_that(assertthat::is.string(selector))
  assertthat::assert_that(
    assertthat::is.number(timeout), timeout > 0,
    msg = "`timeout` must be a single positive number"
  )
  assertthat::assert_that(assertthat::is.flag(visible))

  if (is.null(id))
    id <- gsub("[^A-Za-z0-9]", "_", selector)

  if (is.null(session))
    session <- shiny::getDefaultReactiveDomain()

  session$sendCustomMessage(
    "cicerone-wait-element",
    list(selector = selector, timeout = timeout, visible = visible, id = id)
  )

  invisible(id)
}
