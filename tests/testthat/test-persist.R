# WP5 unit coverage: `persist`/`version` argument validation,
# `tour_state()`'s cookie parsing, and both persistence backends'
# read/write/forget wiring.
#
# The adapter backend's write observers are registered with
# `shiny::observeEvent()` (see `register_persist_observers()` in
# R/steps.R), which needs more from its `domain` than the plain
# environment `make_session()` provides (`isEnded()`, `onEnded()`,
# `reactlog()`, and the flush-scheduling machinery). Rather than
# hand-rolling all of that onto the shared mock, tests that need a real
# `observeEvent()` to fire use `shiny::MockShinySession` (shiny's own,
# exported test double, built for exactly this). Tests for the
# record-building logic itself call the private `persist_on_*` methods
# directly -- no reactive context needed at all.

# --- helpers ------------------------------------------------------------

# Build a `Cookie:` header string with a `cicerone=` entry for `map` (a
# named list of tour id -> record), optionally alongside another cookie.
cookie_header <- function(map, other = NULL) {
  json <- as.character(jsonlite::toJSON(map, auto_unbox = TRUE))
  value <- utils::URLencode(json, reserved = TRUE)
  entry <- paste0("cicerone=", value)
  if (is.null(other)) entry else paste0(other, "; ", entry)
}

session_with_cookie <- function(header) {
  s <- make_session()
  s$request <- list(HTTP_COOKIE = header)
  s
}

# `shiny::MockShinySession` (shiny's own exported test double) for tests
# that need a real `observeEvent()` to register/fire -- `make_session()`
# alone is not enough for that (see the header comment above). Its own
# `sendCustomMessage()` is a no-op stub (with its own warning), so
# replace it with the same recorder `make_session()` uses, to keep
# assertions on `$msgs` consistent across every test in this file.
mock_session <- function() {
  s <- shiny::MockShinySession$new()
  s$msgs <- list()
  s$sendCustomMessage <- function(type, message) {
    s$msgs[[length(s$msgs) + 1]] <- list(type = type, message = message)
  }
  s
}

# a persist adapter that records every call it receives
recording_adapter <- function(read_value = NULL, fail = character(0)) {
  calls <- new.env()
  calls$read <- list()
  calls$write <- list()
  calls$forget <- list()

  list(
    calls = calls,
    read = function(id) {
      calls$read[[length(calls$read) + 1]] <- id
      if ("read" %in% fail) stop("read boom")
      read_value
    },
    write = function(id, record) {
      calls$write[[length(calls$write) + 1]] <- list(id = id, record = record)
      if ("write" %in% fail) stop("write boom")
    },
    forget = function(id) {
      calls$forget[[length(calls$forget) + 1]] <- id
      if ("forget" %in% fail) stop("forget boom")
    }
  )
}

# --- persist/version argument validation --------------------------------

test_that("persist accepts NULL, \"cookie\", or a complete read/write/forget list", {
  expect_silent(Cicerone$new(id = "v1"))
  expect_silent(Cicerone$new(id = "v2", persist = "cookie"))
  expect_silent(Cicerone$new(
    id = "v3",
    persist = list(read = function(id) NULL, write = function(id, r) NULL, forget = function(id) NULL)
  ))
})

test_that("an invalid persist value errors", {
  expect_error(Cicerone$new(id = "v4", persist = "bogus"))
  expect_error(Cicerone$new(id = "v5", persist = TRUE))
  expect_error(Cicerone$new(id = "v6", persist = list(read = function(id) NULL)))
  expect_error(Cicerone$new(
    id = "v7",
    persist = list(read = 1, write = function(id, r) NULL, forget = function(id) NULL)
  ))
})

test_that("persist with an auto-generated id errors", {
  expect_error(Cicerone$new(persist = "cookie"), "id")
  expect_error(Cicerone$new(persist = list(
    read = function(id) NULL, write = function(id, r) NULL, forget = function(id) NULL
  )), "id")
})

test_that("version must be a single positive whole number", {
  expect_silent(Cicerone$new(id = "v8", version = 2))
  expect_error(Cicerone$new(id = "v9", version = 0))
  expect_error(Cicerone$new(id = "v10", version = -1))
  expect_error(Cicerone$new(id = "v11", version = 1.5))
  expect_error(Cicerone$new(id = "v12", version = "1"))
})

# --- tour_state() ---------------------------------------------------------

test_that("tour_state() reads a record by id out of a two-tour cookie", {
  header <- cookie_header(list(
    tourA = list(v = 1, status = "completed", idx = 2, n = 1, t = "2026-01-01T00:00:00Z"),
    tourB = list(v = 1, status = "in_progress", idx = 0, n = 2, t = "2026-02-02T00:00:00Z")
  ))
  s <- session_with_cookie(header)

  a <- tour_state(session = s, id = "tourA")
  expect_equal(a$status, "completed")
  expect_equal(a$idx, 2)

  b <- tour_state(session = s, id = "tourB")
  expect_equal(b$status, "in_progress")
  expect_equal(b$n, 2)

  expect_null(tour_state(session = s, id = "no_such_tour"))
})

test_that("tour_state() with no id returns every persisted tour", {
  header <- cookie_header(list(
    tourA = list(v = 1, status = "completed", idx = 2, n = 1, t = "2026-01-01T00:00:00Z"),
    tourB = list(v = 1, status = "in_progress", idx = 0, n = 2, t = "2026-02-02T00:00:00Z")
  ))
  s <- session_with_cookie(header)

  all_records <- tour_state(session = s)
  expect_setequal(names(all_records), c("tourA", "tourB"))
})

test_that("tour_state() ignores a version mismatch: it reads the raw record unfiltered", {
  header <- cookie_header(list(tourA = list(v = 1, status = "completed", idx = 2, n = 1, t = "x")))
  s <- session_with_cookie(header)

  # tour_state() has no tour object to compare `v` against, so the
  # mismatch check (the package does not migrate) is the caller's job,
  # not tour_state()'s -- see Cicerone$init()/cicerone-init in tour.js
  record <- tour_state(session = s, id = "tourA")
  expect_equal(record$v, 1)
})

test_that("tour_state() tolerates malformed JSON", {
  s <- session_with_cookie("cicerone=%7Bnot-json")
  expect_equal(tour_state(session = s), list())
  expect_null(tour_state(session = s, id = "tourA"))
})

test_that("tour_state() tolerates a missing cicerone cookie and a missing cookie header entirely", {
  s <- session_with_cookie("other=1; another=2")
  expect_equal(tour_state(session = s), list())

  s2 <- session_with_cookie(NULL)
  expect_equal(tour_state(session = s2), list())

  s3 <- make_session() # no $request at all
  expect_equal(tour_state(session = s3), list())
})

test_that("tour_state() falls back to the default reactive domain", {
  s <- session_with_cookie(cookie_header(list(tourA = list(v = 1, status = "completed", idx = 0, n = 1, t = "x"))))
  out <- shiny::withReactiveDomain(s, tour_state(id = "tourA"))
  expect_equal(out$status, "completed")
})

# --- $init()/$start()/$forget() payloads (cookie backend + no persistence) ----

test_that("persist = \"cookie\" sends persist/version/runOnce in the init payload", {
  s <- make_session()
  g <- Cicerone$new(id = "c1", persist = "cookie", version = 3)$step("plot", title = "x")
  g$init(session = s, run_once = TRUE)

  msg <- s$msgs[[1]]
  expect_equal(msg$type, "cicerone-init")
  expect_equal(msg$message$persist, "cookie")
  expect_equal(msg$message$version, 3)
  expect_true(msg$message$runOnce)

  # cookie backend: no separate persist-record push, JS reads document.cookie itself
  expect_false(any(vapply(s$msgs, function(m) m$type == "cicerone-persist-record", logical(1))))
})

test_that("persist = NULL sends no persist mode and no persist-record push", {
  s <- make_session()
  g <- Cicerone$new(id = "c2")$step("plot", title = "x")
  g$init(session = s)

  msg <- s$msgs[[1]]
  expect_null(msg$message$persist)
  expect_false(any(vapply(s$msgs, function(m) m$type == "cicerone-persist-record", logical(1))))
})

test_that("$start(resume = TRUE) sends resume = TRUE in the cicerone-start payload", {
  s <- make_session()
  g <- Cicerone$new(id = "c3", persist = "cookie")$step("plot", title = "x")
  g$init(session = s)
  g$start(session = s, resume = TRUE)

  msg <- s$msgs[[2]]
  expect_equal(msg$type, "cicerone-start")
  expect_true(msg$message$resume)
})

test_that("$start() defaults resume to FALSE", {
  s <- make_session()
  g <- Cicerone$new(id = "c4")$step("plot", title = "x")
  g$init(session = s)
  g$start(session = s)

  expect_false(s$msgs[[2]]$message$resume)
})

test_that("$forget() is a no-op for the cookie backend beyond sending cicerone-forget", {
  s <- make_session()
  g <- Cicerone$new(id = "c5", persist = "cookie")$step("plot", title = "x")
  g$forget(session = s)

  expect_equal(s$msgs[[1]]$type, "cicerone-forget")
  expect_equal(s$msgs[[1]]$message$id, "c5")
})

test_that("$forget() sends cicerone-forget even with no persistence at all", {
  s <- make_session()
  g <- Cicerone$new(id = "c6")$step("plot", title = "x")
  g$forget(session = s)

  expect_equal(s$msgs[[1]]$type, "cicerone-forget")
})

# --- adapter backend: read()/forget() (no observer registration involved) ----

test_that("$init() reads the adapter's record and pushes it to JS via cicerone-persist-record", {
  s <- mock_session()
  adapter <- recording_adapter(read_value = list(v = 1, status = "completed", idx = 2, n = 3, t = "x"))
  g <- Cicerone$new(id = "a1", persist = adapter, version = 1)$step("plot", title = "x")
  g$init(session = s)

  expect_equal(adapter$calls$read, list("a1"))

  pushed <- Filter(function(m) m$type == "cicerone-persist-record", s$msgs)
  expect_equal(length(pushed), 1)
  expect_equal(pushed[[1]]$message$id, "a1")
  expect_equal(pushed[[1]]$message$record$status, "completed")
})

test_that("$init() treats a version-mismatched adapter record as no record", {
  s <- mock_session()
  adapter <- recording_adapter(read_value = list(v = 1, status = "completed", idx = 2, n = 3, t = "x"))
  g <- Cicerone$new(id = "a2", persist = adapter, version = 2)$step("plot", title = "x")
  g$init(session = s)

  pushed <- Filter(function(m) m$type == "cicerone-persist-record", s$msgs)
  expect_null(pushed[[1]]$message$record)
})

test_that("a throwing persist$read() warns and $init() proceeds with no record", {
  s <- mock_session()
  adapter <- recording_adapter(fail = "read")
  g <- Cicerone$new(id = "a3", persist = adapter)$step("plot", title = "x")

  expect_warning(g$init(session = s), "persist\\$read")

  pushed <- Filter(function(m) m$type == "cicerone-persist-record", s$msgs)
  expect_null(pushed[[1]]$message$record)
})

test_that("$forget() calls the adapter's forget(id) and sends cicerone-forget", {
  s <- make_session()
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "a4", persist = adapter)$step("plot", title = "x")
  g$forget(session = s)

  expect_equal(adapter$calls$forget, list("a4"))
  expect_equal(s$msgs[[1]]$type, "cicerone-forget")
})

test_that("a throwing persist$forget() warns and does not stop $forget()", {
  s <- make_session()
  adapter <- recording_adapter(fail = "forget")
  g <- Cicerone$new(id = "a5", persist = adapter)$step("plot", title = "x")

  expect_warning(g$forget(session = s), "persist\\$forget")
  expect_equal(s$msgs[[1]]$type, "cicerone-forget")
})

# --- adapter backend: record-building, called directly (no reactivity) ----

test_that("persist_on_started builds an in_progress record and increments n", {
  s <- make_session()
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "b1", persist = adapter, version = 1)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  priv$persist_on_started(list(index = 0, total_steps = 3))
  rec1 <- adapter$calls$write[[1]]
  expect_equal(rec1$id, "b1")
  expect_equal(rec1$record$status, "in_progress")
  expect_equal(rec1$record$idx, 0)
  expect_equal(rec1$record$n, 1)
  expect_equal(rec1$record$v, 1)

  # a second $start() (a second `_started`) bumps n again
  priv$persist_on_started(list(index = 0, total_steps = 3))
  rec2 <- adapter$calls$write[[2]]
  expect_equal(rec2$record$n, 2)
})

test_that("persist_on_state updates idx without touching status or n", {
  s <- make_session()
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "b2", persist = adapter)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  priv$persist_on_started(list(index = 0, total_steps = 3))
  priv$persist_on_state(list(index = 1, total_steps = 3, highlighted = "el2"))

  rec <- adapter$calls$write[[2]]
  expect_equal(rec$record$status, "in_progress")
  expect_equal(rec$record$idx, 1)
  expect_equal(rec$record$n, 1)
})

test_that("persist_on_state then persist_on_started (the actual bridge.js emission order) still lands n = 1", {
  # bridge.js's onHighlighted emits `_state` BEFORE `_started` (see
  # tour.js's cicerone-init: `emitInput(id, "state", ...)` runs
  # unconditionally, ahead of the `if (!active[id])` block that emits
  # `_started`), and Shiny does not guarantee `persist_on_started`'s
  # observer runs before `persist_on_state`'s in the resulting flush.
  # An e2e run surfaced this as a real bug: n reached 2 on the very
  # first `$start()` before persist_on_state's own "no prior record"
  # fallback for `n` was fixed from 1L to 0L (see persist_on_state).
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "b2b", persist = adapter)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  priv$persist_on_state(list(index = 0, total_steps = 3, highlighted = "el1"))
  priv$persist_on_started(list(index = 0, total_steps = 3))

  final <- adapter$calls$write[[length(adapter$calls$write)]]
  expect_equal(final$record$n, 1)
  expect_equal(final$record$status, "in_progress")
})

test_that("persist_on_ended maps reason 'done' to status 'completed'", {
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "b3", persist = adapter)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  priv$persist_on_started(list(index = 0, total_steps = 1))
  priv$persist_on_ended(list(reason = "done", completed = TRUE, index = 0, total_steps = 1))

  rec <- adapter$calls$write[[2]]
  expect_equal(rec$record$status, "completed")
})

test_that("persist_on_ended maps every non-done, non-suppressed reason to status 'dismissed'", {
  for (reason in c("close", "programmatic", "superseded", "dismissed")) {
    adapter <- recording_adapter()
    g <- Cicerone$new(id = paste0("b4_", reason), persist = adapter)$step("plot", title = "x")
    priv <- g$.__enclos_env__$private

    priv$persist_on_started(list(index = 0, total_steps = 1))
    priv$persist_on_ended(list(reason = reason, completed = FALSE, index = 0, total_steps = 1))

    rec <- adapter$calls$write[[2]]
    expect_equal(rec$record$status, "dismissed")
  }
})

test_that("persist_on_ended with reason 'suppressed' writes nothing", {
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "b5", persist = adapter)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  priv$persist_on_ended(list(reason = "suppressed", completed = FALSE, index = NULL, total_steps = 1))

  expect_equal(length(adapter$calls$write), 0)
})

test_that("a throwing persist$write() warns and does not stop the record update", {
  adapter <- recording_adapter(fail = "write")
  g <- Cicerone$new(id = "b6", persist = adapter)$step("plot", title = "x")
  priv <- g$.__enclos_env__$private

  expect_warning(priv$persist_on_started(list(index = 0, total_steps = 1)), "persist\\$write")
})

# --- adapter backend: end-to-end observer wiring, via MockShinySession ----

test_that("$init() wires real observeEvent()s that call persist$write() on _started/_state/_ended", {
  s <- mock_session()
  adapter <- recording_adapter()
  g <- Cicerone$new(id = "e1", persist = adapter)$step("plot", title = "x")
  g$init(session = s)

  # the observers' own first (ignoreInit-skipped) run is pending in the
  # flush queue as soon as they are registered; flush it now, before any
  # real input is set, so it does not consume the real event below
  s$flushReact()

  s$setInputs(e1_cicerone_started = list(index = 0, total_steps = 1))
  expect_equal(length(adapter$calls$write), 1)
  expect_equal(adapter$calls$write[[1]]$record$status, "in_progress")

  s$setInputs(e1_cicerone_state = list(index = 0, total_steps = 1, highlighted = "el1"))
  expect_equal(length(adapter$calls$write), 2)

  s$setInputs(e1_cicerone_ended = list(reason = "done", completed = TRUE, index = 0, total_steps = 1))
  expect_equal(length(adapter$calls$write), 3)
  expect_equal(adapter$calls$write[[3]]$record$status, "completed")
})
