#!/usr/bin/env Rscript
# Regenerate every README media asset in man/figures/ from the showcase app
# (inst/examples/demo/app.R). Not shipped -- `^dev$` is in .Rbuildignore.
#
# Usage:
#   Rscript dev/media/record.R
#
# Requires (see readme-refresh-plan.md section 3): shinytest2 + chromote
# for driving a real headless Chrome, ffmpeg on PATH for frames -> GIF/PNG.
# The package itself must be installed from this worktree first, since
# shinytest2 launches the app in a separate R process (see the header
# comment in tests/testthat/helper-e2e.R for why):
#
#   Rscript -e 'install.packages(".", repos = NULL, type = "source")'
#
# Regenerates:
#   man/figures/tour.gif        3-step tour, tab switch, progress bar, Done
#   man/figures/advance-on.gif  typing advances the tour with no Next click
#   man/figures/hints.gif       beacon -> popover -> dismissed by its button
#   man/figures/theme.png       default vs bootstrap-preset/dark, side by side
#
# Each recording launches its own AppDriver (a fresh R process + a fresh
# Chrome tab), so nothing here depends on another asset's leftover state.

library(shinytest2)
library(processx)

FFMPEG <- "/opt/homebrew/bin/ffmpeg"
APP_DIR <- "inst/examples/demo"
FIG_DIR <- "man/figures"
BUDGET_GIF_BYTES <- 1.5 * 1024^2
BUDGET_GIF_SECONDS <- 8
BUDGET_STILL_BYTES <- 300 * 1024

new_app <- function() {
  AppDriver$new(APP_DIR, width = 1000, height = 640, load_timeout = 20000, view = FALSE)
}

new_frame_dir <- function() {
  d <- file.path(tempdir(), sprintf(
    "cicerone-frames-%s", paste(sample(c(letters, 0:9), 8, TRUE), collapse = "")
  ))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# processx::run(), not system2(): system2() reconstructs a shell command
# line internally, and on this R/macOS combination that mishandles a
# filtergraph argument containing `;`/`[`/`]` (confirmed by direct
# reproduction -- ffmpeg's own filtergraph parser then errors with
# "output 0 (x) unconnected"), even though the identical argv run without
# a shell (or pasted into one by hand) works. processx execs the argv
# vector directly, no shell involved.
run_ffmpeg <- function(args) {
  res <- processx::run(FFMPEG, args, error_on_status = FALSE)
  if (res$status != 0) {
    stop("ffmpeg failed:\n", res$stderr, call. = FALSE)
  }
  invisible(res$stderr)
}

# Screenshot every `interval_ms` for `duration_ms`, numbering frames
# sequentially from `ctr$i` so repeated calls in one scenario build one
# continuous sequence (a hold, then a transition, then another hold, ...).
capture_frames <- function(app, dir, ctr, duration_ms, interval_ms = 250) {
  n <- max(1L, round(duration_ms / interval_ms))
  for (i in seq_len(n)) {
    Sys.sleep(interval_ms / 1000)
    ctr$i <- ctr$i + 1L
    app$get_screenshot(file.path(dir, sprintf("frame_%04d.png", ctr$i)))
  }
  invisible(ctr)
}

# Two-pass palette GIF (see readme-refresh-plan.md section 3): palettegen
# then paletteuse, scaled to 900px wide. `fps` is both the frame rate
# ffmpeg assumes for the numbered input sequence and the output GIF's
# playback rate.
#' `input_fps` must match the real capture cadence (1000 / interval_ms in
#' `capture_frames()`) so ffmpeg's frame timestamps -- and so the GIF's
#' total duration -- reflect real elapsed time; `fps` is the display rate
#' the `fps=` filter resamples to (upsampling here, by duplicating frames,
#' since capture_frames()'s default interval is slower than 8fps).
frames_to_gif <- function(dir, out, fps = 8, input_fps = 4) {
  pattern <- file.path(dir, "frame_%04d.png")
  palette <- file.path(dir, "palette.png")
  run_ffmpeg(c(
    "-y", "-start_number", "1", "-framerate", as.character(input_fps), "-i", pattern,
    "-vf", sprintf("fps=%d,scale=900:-1:flags=lanczos,palettegen=max_colors=128", fps),
    palette
  ))
  run_ffmpeg(c(
    "-y", "-start_number", "1", "-framerate", as.character(input_fps), "-i", pattern,
    "-i", palette,
    "-lavfi", sprintf(
      "[0:v]fps=%d,scale=900:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer", fps
    ),
    out
  ))
  invisible(out)
}

image_height <- function(path) {
  res <- processx::run(
    sub("ffmpeg$", "ffprobe", FFMPEG),
    c(
      "-v", "error", "-select_streams", "v:0", "-show_entries",
      "stream=height", "-of", "csv=p=0", path
    ),
    error_on_status = FALSE
  )
  as.integer(strsplit(res$stdout, "\n")[[1]][1])
}

gif_duration_seconds <- function(path) {
  res <- processx::run(
    sub("ffmpeg$", "ffprobe", FFMPEG),
    c(
      "-v", "error", "-select_streams", "v:0", "-show_entries",
      "format=duration", "-of", "csv=p=0", path
    ),
    error_on_status = FALSE
  )
  suppressWarnings(as.numeric(strsplit(res$stdout, "\n")[[1]][1]))
}

# ---- man/figures/tour.gif ---------------------------------------------------
# Start the main tour, step through all 3 steps (advance_on, a tab switch,
# the show_if-gated step), click Done.
record_tour <- function() {
  app <- new_app(); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  capture_frames(app, dir, ctr, duration_ms = 1000) # step 1: hold

  app$run_js(
    "var el = document.querySelector('#name');
     el.value = 'Ada'; el.dispatchEvent(new Event('input', {bubbles: true}));"
  )
  capture_frames(app, dir, ctr, duration_ms = 1200) # advance + tab switch + hold

  app$run_js("document.querySelector('.driver-popover-next-btn').click()")
  capture_frames(app, dir, ctr, duration_ms = 1000) # step 3: hold

  app$run_js("document.querySelector('.driver-popover-next-btn').click()") # Done
  capture_frames(app, dir, ctr, duration_ms = 500) # closing

  out <- file.path(FIG_DIR, "tour.gif")
  frames_to_gif(dir, out, fps = 8)
  unlink(dir, recursive = TRUE)
  out
}

# ---- man/figures/advance-on.gif ---------------------------------------------
# Start the tour, type into the field, watch it advance with no Next click.
# The listener is armed once per highlight (`{once: true}`), so the very
# first keystroke is enough to demonstrate it.
record_advance_on <- function() {
  app <- new_app(); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  capture_frames(app, dir, ctr, duration_ms = 1200) # step 1: hold, empty field

  app$run_js(
    "var el = document.querySelector('#name');
     el.value = 'A'; el.dispatchEvent(new Event('input', {bubbles: true}));"
  )
  capture_frames(app, dir, ctr, duration_ms = 1500) # advance + tab switch + hold

  out <- file.path(FIG_DIR, "advance-on.gif")
  frames_to_gif(dir, out, fps = 8)
  unlink(dir, recursive = TRUE)
  out
}

# ---- man/figures/hints.gif ---------------------------------------------------
# Show beacons, click one, its popover opens, click its button, it dismisses.
record_hints <- function() {
  app <- new_app(); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$click("btn_hints")
  app$wait_for_js("document.querySelectorAll('.driver-hint').length > 0")
  capture_frames(app, dir, ctr, duration_ms = 1000) # beacons: hold

  app$run_js("document.querySelector('.driver-hint').click()")
  capture_frames(app, dir, ctr, duration_ms = 1200) # popover open: hold

  app$run_js("document.querySelector('.driver-popover-next-btn').click()")
  capture_frames(app, dir, ctr, duration_ms = 600) # dismissed

  out <- file.path(FIG_DIR, "hints.gif")
  frames_to_gif(dir, out, fps = 8)
  unlink(dir, recursive = TRUE)
  out
}

# ---- man/figures/theme.png ---------------------------------------------------
# The same popover, default theme vs cicerone_theme(preset = "bootstrap")
# under dark mode, hstacked into one still. `data-bs-theme` is forced
# explicitly in both directions: headless Chrome's default color-scheme
# is not guaranteed light, so leaving it on "auto" is not reproducible.
record_theme <- function() {
  app <- new_app(); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir()

  app$run_js("document.documentElement.setAttribute('data-bs-theme', 'light')")
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.6)
  left <- file.path(dir, "default.png")
  app$get_screenshot(left, selector = ".driver-popover")

  app$run_js("document.querySelector('.driver-popover-close-btn').click()")
  app$wait_for_js("document.querySelector('.driver-popover') === null")

  app$set_inputs(theme_bootstrap = TRUE)
  app$run_js("document.documentElement.setAttribute('data-bs-theme', 'dark')")
  Sys.sleep(0.3)
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.6)
  right <- file.path(dir, "bootstrap-dark.png")
  app$get_screenshot(right, selector = ".driver-popover")

  # hstack requires equal input heights; the two popovers differ by a few
  # px (theme changes affect box-model rounding), so scale both to the
  # taller one's height first, preserving aspect ratio.
  target_h <- max(image_height(left), image_height(right))
  out <- file.path(FIG_DIR, "theme.png")
  run_ffmpeg(c(
    "-y", "-i", left, "-i", right, "-filter_complex", sprintf(
      "[0:v]scale=-1:%d:flags=lanczos[a];[1:v]scale=-1:%d:flags=lanczos[b];[a][b]hstack=inputs=2",
      target_h, target_h
    ),
    out
  ))
  unlink(dir, recursive = TRUE)
  out
}

# ---- run everything, report sizes -------------------------------------------
if (identical(Sys.getenv("NOT_CRAN"), "")) Sys.setenv(NOT_CRAN = "true")

assets <- list(
  list(name = "tour.gif", fn = record_tour, budget = BUDGET_GIF_BYTES, is_gif = TRUE),
  list(name = "advance-on.gif", fn = record_advance_on, budget = BUDGET_GIF_BYTES, is_gif = TRUE),
  list(name = "hints.gif", fn = record_hints, budget = BUDGET_GIF_BYTES, is_gif = TRUE),
  list(name = "theme.png", fn = record_theme, budget = BUDGET_STILL_BYTES, is_gif = FALSE)
)

cat("Regenerating cicerone README media assets...\n\n")
for (asset in assets) {
  cat(sprintf("-- %s --\n", asset$name))
  path <- asset$fn()
  size <- file.info(path)$size
  over_budget <- size > asset$budget
  line <- sprintf("   size: %.1f KB (budget %.1f KB)%s",
    size / 1024, asset$budget / 1024, if (over_budget) " OVER BUDGET" else "")
  if (asset$is_gif) {
    dur <- gif_duration_seconds(path)
    over_time <- !is.na(dur) && dur > BUDGET_GIF_SECONDS
    line <- paste0(line, sprintf(
      ", duration: %.1fs (budget %ds)%s",
      dur, BUDGET_GIF_SECONDS, if (over_time) " OVER BUDGET" else ""
    ))
  }
  cat(line, "\n\n")
}
cat("Done. Assets written to", FIG_DIR, "\n")
