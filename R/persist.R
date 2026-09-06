# WP5: cookie-backend persistence, R side.
#
# The cookie itself is written and rewritten entirely by JavaScript
# (srcjs/exts/persist.js) -- a live session never sees its own writes
# reflected back in `session$request` until reconnect (the WebSocket
# handshake headers, including `Cookie`, are captured once, at connection
# time; see `tour_state()` below). `tour_state()` is the one R-side reader:
# a synchronous, server-side view of whatever cookie the browser sent with
# the CURRENT page load/reconnect, useful for e.g. rendering something
# different on first paint for a user who has already completed a tour,
# without waiting for the `{id}_cicerone_seen` input to arrive.

# Parse the `cicerone` cookie's value out of a raw `Cookie:` header string
# into a named list keyed by tour id, e.g.:
# `list(my_tour = list(v = 1, status = "completed", idx = 2, n = 1L, t = "..."))`.
# Never errors: a missing cookie, a missing `cicerone` entry, a value that
# fails to URL-decode, or a value that is not valid JSON all return an
# empty named list, the same as "no persisted tours at all".
parse_cicerone_cookie <- function(header) {
  empty <- list()

  if (is.null(header) || !is.character(header) || length(header) != 1L || !nzchar(header))
    return(empty)

  m <- regexec("(?:^|;\\s*)cicerone=([^;]*)", header, perl = TRUE)
  matched <- regmatches(header, m)[[1]]
  if (length(matched) < 2L || !nzchar(matched[2]))
    return(empty)

  decoded <- tryCatch(utils::URLdecode(matched[2]), error = function(e) NULL)
  if (is.null(decoded) || !nzchar(decoded))
    return(empty)

  parsed <- tryCatch(
    jsonlite::fromJSON(decoded, simplifyVector = FALSE),
    error = function(e) NULL
  )
  if (!is.list(parsed))
    return(empty)

  parsed
}

#' Read persisted tour state from the request cookie
#'
#' Reads the `cicerone` cookie set by a [Cicerone] tour created with
#' `persist = "cookie"` (see `?Cicerone`), parsed from
#' `session$request$HTTP_COOKIE` -- the raw `Cookie:` header Shiny
#' captured at WebSocket handshake time.
#'
#' This is a synchronous, server-side read, available before any UI is
#' sent (e.g. from inside the server function, to decide what to render
#' on first paint). It reflects whatever cookie the browser sent when
#' the current session connected or reconnected; it does NOT reflect a
#' write a tour made earlier in the SAME live session (the browser does
#' not resend its `Cookie` header mid-connection). For that, use the
#' live `{id}_cicerone_seen` input instead (see [cicerone_inputs]).
#'
#' `tour_state()` does not check a record's `v` (version) against
#' anything -- it has no tour object to compare against, so it returns
#' whatever is stored, unfiltered. A [Cicerone] tour's own version check
#' (which decides `{id}_cicerone_seen`, `run_once` suppression, and
#' `resume`) happens separately, at `$init()`/`$start()`.
#'
#' @param session A valid Shiny session if `NULL` the function
#' attempts to get the session with [shiny::getDefaultReactiveDomain()].
#' @param id A tour's `id`. If `NULL`, returns every persisted tour's
#' record, as a named list keyed by `id`.
#'
#' @return If `id` is given: that tour's record (`list(v, status, idx,
#' n, t)`), or `NULL` if there is none. If `id` is `NULL`: a named list
#' of every persisted tour's record (possibly empty).
#'
#' @seealso [Cicerone], [cicerone_inputs]
#'
#' @export
tour_state <- function(session = NULL, id = NULL) {
  if (is.null(session))
    session <- shiny::getDefaultReactiveDomain()

  header <- NULL
  if (!is.null(session) && !is.null(session$request))
    header <- session$request$HTTP_COOKIE

  records <- parse_cicerone_cookie(header)

  if (is.null(id))
    return(records)

  records[[id]]
}
