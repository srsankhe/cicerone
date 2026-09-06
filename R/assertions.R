tabs_ok <- function(x, y) {
  total <- sum(length(x), length(y))

  total != 1
}

on_failure(tabs_ok) <- function(call, env) {
  paste0("Either do not define either", deparse(call$x), " and ", deparse(call$y), "or define both.")
}

# WP5: `Cicerone$new(persist = )` accepts NULL, "cookie", or
# list(read = , write = , forget = ) with all three present as functions.
persist_ok <- function(x) {
  if (is.null(x)) return(TRUE)
  if (identical(x, "cookie")) return(TRUE)

  if (is.list(x)) {
    needed <- c("read", "write", "forget")
    return(
      all(needed %in% names(x)) &&
        all(vapply(x[needed], is.function, logical(1)))
    )
  }

  FALSE
}

on_failure(persist_ok) <- function(call, env) {
  paste0(
    "`persist` must be `NULL`, \"cookie\", or ",
    "list(read = , write = , forget = ) with all three as functions"
  )
}