# count non-overlapping occurrences of a fixed substring
count_occurrences <- function(text, pattern) {
  length(regmatches(text, gregexpr(pattern, text, fixed = TRUE))[[1]])
}

test_that("a single argument emits exactly one variable and no others", {
  out <- as.character(cicerone_theme(accent = "#ff0000"))

  expect_equal(count_occurrences(out, "--cicerone-accent: #ff0000"), 1)
  expect_equal(count_occurrences(out, "--cicerone-"), 1)
})

test_that("multiple arguments are all emitted, each exactly once", {
  out <- as.character(cicerone_theme(
    surface = "#111", text = "#eee", radius = "12px"
  ))

  expect_equal(count_occurrences(out, "--cicerone-surface: #111"), 1)
  expect_equal(count_occurrences(out, "--cicerone-text: #eee"), 1)
  expect_equal(count_occurrences(out, "--cicerone-radius: 12px"), 1)
  expect_equal(count_occurrences(out, "--cicerone-"), 3)
})

test_that("no arguments emits an empty style block", {
  out <- as.character(cicerone_theme())
  expect_equal(count_occurrences(out, "--cicerone-"), 0)
})

test_that("preset = 'bootstrap' emits --bs- references for every variable", {
  out <- as.character(cicerone_theme(preset = "bootstrap"))

  expect_equal(count_occurrences(out, "--cicerone-"), 11)
  expect_equal(count_occurrences(out, "var(--bs-"), 11)
  expect_match(out, "--cicerone-surface: var(--bs-body-bg)", fixed = TRUE)
  expect_match(out, "--cicerone-btn-text: var(--bs-white)", fixed = TRUE)
})

test_that("an explicit argument overrides the bootstrap preset for that property only", {
  out <- as.character(cicerone_theme(preset = "bootstrap", accent = "#ff0000"))

  expect_match(out, "--cicerone-accent: #ff0000", fixed = TRUE)
  expect_false(grepl("--cicerone-accent: var(--bs-primary)", out, fixed = TRUE))
  # every other property still comes from the preset
  expect_match(out, "--cicerone-surface: var(--bs-body-bg)", fixed = TRUE)
  expect_equal(count_occurrences(out, "--cicerone-"), 11)
})

test_that("an invalid preset errors", {
  expect_error(cicerone_theme(preset = "material"))
})

test_that("an invalid argument name errors", {
  expect_error(cicerone_theme(colour = "#ff0000"))
})

test_that("selector is used, defaulting to .driver-popover", {
  default_out <- as.character(cicerone_theme(accent = "red"))
  expect_match(default_out, "<style>.driver-popover {", fixed = TRUE)

  out <- as.character(cicerone_theme(accent = "red", selector = ".e2e-themed"))
  expect_match(out, "<style>.e2e-themed {", fixed = TRUE)
  expect_false(grepl(".driver-popover", out, fixed = TRUE))
})
