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

test_that("preset = 'bootstrap' emits --bs- references for every mapped variable", {
  out <- as.character(cicerone_theme(preset = "bootstrap"))

  # 11 pre-WP10 --cicerone-* properties + 5 new ones (line_height,
  # btn_font_size, btn_border, btn_radius, btn_hover_bg) the preset maps.
  # font_family is a --driver-popover-font-family property, not
  # --cicerone-*, so it adds var(--bs- reference(s) without counting
  # towards the --cicerone- total. btn_border's value itself contains
  # two var(--bs- references (border-width and border-color), so the
  # var(--bs- total is 18, not 16: 15 properties x 1 + btn_border's 2 +
  # font_family's 1.
  expect_equal(count_occurrences(out, "--cicerone-"), 16)
  expect_equal(count_occurrences(out, "var(--bs-"), 18)
  expect_match(out, "--cicerone-surface: var(--bs-body-bg)", fixed = TRUE)
  expect_match(out, "--cicerone-btn-text: var(--bs-white)", fixed = TRUE)
  expect_match(out, "--driver-popover-font-family: var(--bs-body-font-family)", fixed = TRUE)
  expect_match(out, "--cicerone-line-height: var(--bs-body-line-height)", fixed = TRUE)
  expect_match(out, "--cicerone-btn-font-size: var(--bs-body-font-size)", fixed = TRUE)
  expect_match(
    out, "--cicerone-btn-border: var(--bs-border-width) solid var(--bs-border-color)",
    fixed = TRUE
  )
  expect_match(out, "--cicerone-btn-radius: var(--bs-border-radius)", fixed = TRUE)
  expect_match(out, "--cicerone-btn-hover-bg: var(--bs-tertiary-bg)", fixed = TRUE)

  # no root-scoped Bootstrap token exists for these -- left unset
  expect_false(grepl("--cicerone-title-size", out, fixed = TRUE))
  expect_false(grepl("--cicerone-title-weight", out, fixed = TRUE))
  expect_false(grepl("--cicerone-max-width", out, fixed = TRUE))
})

test_that("an explicit argument overrides the bootstrap preset for that property only", {
  out <- as.character(cicerone_theme(preset = "bootstrap", accent = "#ff0000"))

  expect_match(out, "--cicerone-accent: #ff0000", fixed = TRUE)
  expect_false(grepl("--cicerone-accent: var(--bs-primary)", out, fixed = TRUE))
  # every other property still comes from the preset
  expect_match(out, "--cicerone-surface: var(--bs-body-bg)", fixed = TRUE)
  expect_equal(count_occurrences(out, "--cicerone-"), 16)
})

test_that("an explicit new-argument override wins over the bootstrap preset", {
  out <- as.character(cicerone_theme(preset = "bootstrap", btn_border = "3px dashed blue"))

  expect_match(out, "--cicerone-btn-border: 3px dashed blue", fixed = TRUE)
  expect_false(grepl("--cicerone-btn-border: var(--bs-border-width)", out, fixed = TRUE))
  # unrelated preset mappings are untouched
  expect_match(out, "--cicerone-btn-radius: var(--bs-border-radius)", fixed = TRUE)
})

test_that("font_family emits --driver-popover-font-family, not --cicerone-font-family", {
  out <- as.character(cicerone_theme(font_family = "Georgia, serif"))

  expect_equal(count_occurrences(out, "--driver-popover-font-family: Georgia, serif"), 1)
  expect_false(grepl("--cicerone-font-family", out, fixed = TRUE))
  expect_equal(count_occurrences(out, "--cicerone-"), 0)
})

test_that("each new typography/layout argument emits exactly one declaration", {
  out <- as.character(cicerone_theme(
    title_size = "24px", title_weight = "800", line_height = "1.6",
    btn_font_size = "13px", btn_border = "2px solid red",
    btn_radius = "6px", btn_hover_bg = "#eee", max_width = "400px"
  ))

  expect_equal(count_occurrences(out, "--cicerone-title-size: 24px"), 1)
  expect_equal(count_occurrences(out, "--cicerone-title-weight: 800"), 1)
  expect_equal(count_occurrences(out, "--cicerone-line-height: 1.6"), 1)
  expect_equal(count_occurrences(out, "--cicerone-btn-font-size: 13px"), 1)
  expect_equal(count_occurrences(out, "--cicerone-btn-border: 2px solid red"), 1)
  expect_equal(count_occurrences(out, "--cicerone-btn-radius: 6px"), 1)
  expect_equal(count_occurrences(out, "--cicerone-btn-hover-bg: #eee"), 1)
  expect_equal(count_occurrences(out, "--cicerone-max-width: 400px"), 1)
  expect_equal(count_occurrences(out, "--cicerone-"), 8)
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
