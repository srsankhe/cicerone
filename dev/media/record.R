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

# `width`/`height` default to the still-capture viewport (`record_theme()`);
# the three GIF recordings pass a smaller 860x480 (media-ux-review.md #5) so
# the highlighted card fills more of the frame instead of empty gray overlay.
new_app <- function(width = 1000, height = 640) {
  AppDriver$new(APP_DIR, width = width, height = height, load_timeout = 20000, view = FALSE)
}

# The showcase app's own input_dark_mode() default is "light", but headless
# Chrome's color-scheme is not guaranteed light, and bslib's dark-mode
# widget follows the OS preference on top of that default in some
# versions -- force it explicitly so recordings are reproducible
# regardless of the machine/Chrome version running this script.
FORCE_LIGHT_JS <- "document.documentElement.setAttribute('data-bs-theme', 'light')"
FORCE_DARK_JS <- "document.documentElement.setAttribute('data-bs-theme', 'dark')"

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
# `screenshot_args = list(scale = 2)` captures at 2x the CSS-pixel
# resolution (media-ux-review.md #6) so popover text survives the
# capture->900px and GitHub's ~800px-render downscales without going soft
# -- the same technique `record_theme()` already used for `theme.png`.
#
# `selector = "viewport"` + `options = list(captureBeyondViewport = FALSE)`:
# chromote's screenshot() otherwise defaults to `captureBeyondViewport =
# TRUE` for every capture (shinytest2's own default clip, "scrollable_area",
# asks for the same). Confirmed by repeated reproduction (~1 in 3 runs) and
# bisection on this one flag: with it on, `record_hints()`'s popover
# intermittently closes itself mid-hold with no scripted cause -- driver.js
# hints' own IntersectionObserver (srcjs never touched; this is
# node_modules/driver.js/dist/hints.mjs, function `_()`/`z()`) dismisses a
# hint the moment its target is reported not-intersecting, and the
# beyond-viewport capture is the only thing perturbing that per-frame.
# Pinning the clip to the real viewport removes the transient entirely (14
# consecutive clean runs vs. 3 failures in 9 beforehand).
capture_frames <- function(app, dir, ctr, duration_ms, interval_ms = 250) {
  n <- max(1L, round(duration_ms / interval_ms))
  for (i in seq_len(n)) {
    Sys.sleep(interval_ms / 1000)
    ctr$i <- ctr$i + 1L
    app$get_screenshot(
      file.path(dir, sprintf("frame_%04d.png", ctr$i)),
      selector = "viewport",
      screenshot_args = list(scale = 2, options = list(captureBeyondViewport = FALSE))
    )
  }
  invisible(ctr)
}

# Recorder-only DOM injection (media-ux-review.md #4) -- never touches
# srcjs/ or the shipped cicerone.js. Draws a small fixed-position dot at
# `selector`'s bounding-box center so the viewer can see *what* is about to
# be clicked/typed into. `pulse = FALSE` just (re)positions the dot at
# rest (used for idle holds); `pulse = TRUE` also restarts a 280ms
# scale/opacity keyframe animation, called immediately before every
# `app$click()`/simulated keystroke so a frame captured ~70ms later still
# shows it mid-pulse, while opacity is still high enough (animation just
# started fading from .9 toward 0) to read clearly against any background.
#
# The dot's box-shadow is a white 2px ring plus the specified blue glow --
# not just the review's literal `0 0 0 6px rgba(13,110,253,.25)` -- because
# "Start tour" is styled `btn-primary`, the same blue as the dot itself: a
# frame check (a fresh app$click("btn_start") pulse, extracted and viewed)
# confirmed the pulse is otherwise invisible against that one button,
# failing the "cursor pulse visible before every click" self-check for
# that target. Every other click/keystroke target in these recordings is
# white/light, where the ring is unnecessary but harmless.
pulse_cursor <- function(app, selector, pulse = TRUE) {
  app$run_js(sprintf(
    "(function() {
      var el = document.querySelector('%s');
      if (!el) return;
      var r = el.getBoundingClientRect();
      var cx = r.left + r.width / 2, cy = r.top + r.height / 2;
      var dot = document.getElementById('cicerone-record-cursor');
      if (!dot) {
        dot = document.createElement('div');
        dot.id = 'cicerone-record-cursor';
        dot.style.cssText = 'position:fixed;width:14px;height:14px;' +
          'border-radius:50%%;background:rgba(13,110,253,.65);' +
          'box-shadow:0 0 0 2px #fff, 0 0 0 8px rgba(13,110,253,.25);' +
          'z-index:2147483647;pointer-events:none;';
        document.body.appendChild(dot);
      }
      if (!document.getElementById('cicerone-record-pulse-style')) {
        var style = document.createElement('style');
        style.id = 'cicerone-record-pulse-style';
        style.textContent = '@keyframes cicerone-record-pulse {' +
          '0%% { transform: scale(.6); opacity: .9; }' +
          '100%% { transform: scale(1.4); opacity: 0; }' +
        '}';
        document.head.appendChild(style);
      }
      dot.style.left = (cx - 7) + 'px';
      dot.style.top = (cy - 7) + 'px';
      if (%s) {
        dot.style.animation = 'none';
        void dot.offsetWidth; /* force reflow so re-setting restarts it */
        dot.style.animation = 'cicerone-record-pulse .28s ease-out';
      }
    })();",
    selector, if (pulse) "true" else "false"
  ))
}

# Remove the cursor dot/style at the end of a recording (media-ux-review.md
# #4: "remove the dot node at the end of each recording function").
remove_cursor <- function(app) {
  app$run_js(
    "var d = document.getElementById('cicerone-record-cursor'); if (d) d.remove();
     var s = document.getElementById('cicerone-record-pulse-style'); if (s) s.remove();"
  )
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

image_width <- function(path) {
  res <- processx::run(
    sub("ffmpeg$", "ffprobe", FFMPEG),
    c(
      "-v", "error", "-select_streams", "v:0", "-show_entries",
      "stream=width", "-of", "csv=p=0", path
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
#
# Every scripted event that changes the highlighted step is followed by
# Sys.sleep(0.45) *before* the first capture_frames() call for that
# segment, so driver.js's ~300-400ms popover move animation has fully
# settled before any frame is captured (media-ux-review.md #2 -- the
# previous 250ms sampling interval landed mid-reposition and baked a
# collapsed white box into the GIF).
record_tour <- function() {
  app <- new_app(width = 860, height = 480); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$run_js(FORCE_LIGHT_JS)

  # idle: cursor resting near "Start tour" before anything happens
  pulse_cursor(app, "#btn_start", pulse = FALSE)
  capture_frames(app, dir, ctr, duration_ms = 750) # idle hold

  # cursor pulse + click "Start tour" -- the click itself must be visible
  pulse_cursor(app, "#btn_start", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.45) # settle before capturing (fix #2)
  capture_frames(app, dir, ctr, duration_ms = 1250) # step 1 "Say hello" hold

  # cursor pulse on #name, type "A" then "Ada" without dispatching `input`
  # until the final value is on screen. advance_on's listener is
  # `{once: true}` on the raw `input` event (srcjs/exts/advance.js) and
  # fires synchronously, so an earlier dispatch would advance the tour
  # after the very first keystroke and "Ada" would never appear on step 1
  # (media-ux-review.md #3).
  pulse_cursor(app, "#name", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('#name').value = 'A';")
  capture_frames(app, dir, ctr, duration_ms = 120, interval_ms = 120) # "A" visible
  app$run_js("document.querySelector('#name').value = 'Ada';")
  capture_frames(app, dir, ctr, duration_ms = 120, interval_ms = 120) # "Ada" visible
  app$run_js(
    "var el = document.querySelector('#name');
     el.dispatchEvent(new Event('input', {bubbles: true}));"
  ) # fires the real advance_on listener now that "Ada" is on screen
  Sys.sleep(0.45) # settle: tab switch + step 2 popover reposition (fix #2)
  capture_frames(app, dir, ctr, duration_ms = 1250) # step 2 "A second tab" hold

  pulse_cursor(app, ".driver-popover-next-btn", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('.driver-popover-next-btn').click()")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.45) # settle (fix #2)
  capture_frames(app, dir, ctr, duration_ms = 1250) # step 3 hold, target on screen (fix #1)

  pulse_cursor(app, ".driver-popover-next-btn", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('.driver-popover-next-btn').click()") # Done
  capture_frames(app, dir, ctr, duration_ms = 500) # closing hold, plain app state

  remove_cursor(app)
  out <- file.path(FIG_DIR, "tour.gif")
  frames_to_gif(dir, out, fps = 8)
  unlink(dir, recursive = TRUE)
  out
}

# ---- man/figures/advance-on.gif ---------------------------------------------
# Start the tour, type into the field character-by-character so the typed
# text is actually visible, watch it advance with no Next click.
record_advance_on <- function() {
  app <- new_app(width = 860, height = 480); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$run_js(FORCE_LIGHT_JS)

  pulse_cursor(app, "#btn_start", pulse = FALSE)
  capture_frames(app, dir, ctr, duration_ms = 250) # idle, cursor near "Start tour"

  pulse_cursor(app, "#btn_start", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.45) # settle before capturing (fix #2)

  pulse_cursor(app, "#name", pulse = FALSE) # idle, cursor near #name, still step 1
  capture_frames(app, dir, ctr, duration_ms = 1000) # step 1 hold, empty field

  # Type character-by-character, setting `value` directly and holding off
  # the real `input` dispatch until the final character -- see the note in
  # record_tour() on advance_on's `{once: true}` listener. This is what
  # actually makes "A" -> "Ad" -> "Ada" visible before the tour advances
  # (media-ux-review.md #3); dispatching `input` on every keystroke, as the
  # review's own JS snippet literally suggests, would fire the listener on
  # the very first keystroke and no progressive text would ever be seen.
  pulse_cursor(app, "#name", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('#name').value = 'A';")
  capture_frames(app, dir, ctr, duration_ms = 120, interval_ms = 120) # "A" visible
  app$run_js("document.querySelector('#name').value = 'Ad';")
  capture_frames(app, dir, ctr, duration_ms = 120, interval_ms = 120) # "Ad" visible
  app$run_js("document.querySelector('#name').value = 'Ada';")
  capture_frames(app, dir, ctr, duration_ms = 120, interval_ms = 120) # "Ada" visible
  capture_frames(app, dir, ctr, duration_ms = 500) # brief hold on filled field, still step 1

  app$run_js(
    "var el = document.querySelector('#name');
     el.dispatchEvent(new Event('input', {bubbles: true}));"
  ) # fires the real advance_on listener now that "Ada" is on screen
  Sys.sleep(0.45) # settle: tab switch + step 2 popover reposition (fix #2)
  capture_frames(app, dir, ctr, duration_ms = 1250) # step 2 hold

  remove_cursor(app)
  out <- file.path(FIG_DIR, "advance-on.gif")
  frames_to_gif(dir, out, fps = 8)
  unlink(dir, recursive = TRUE)
  out
}

# ---- man/figures/hints.gif ---------------------------------------------------
# Show beacons, click one, its popover opens, click its button, it dismisses.
record_hints <- function() {
  app <- new_app(width = 860, height = 480); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir(); ctr <- new.env(); ctr$i <- 0L

  app$run_js(FORCE_LIGHT_JS)

  pulse_cursor(app, "#btn_hints", pulse = FALSE)
  capture_frames(app, dir, ctr, duration_ms = 250) # idle, cursor near "Show hints"

  pulse_cursor(app, "#btn_hints", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$click("btn_hints")
  app$wait_for_js("document.querySelectorAll('.driver-hint').length > 0")
  Sys.sleep(0.45) # settle: let beacons finish animating in (fix #2)

  pulse_cursor(app, ".driver-hint", pulse = FALSE) # idle near Beacon 1
  capture_frames(app, dir, ctr, duration_ms = 750) # beacons: hold

  pulse_cursor(app, ".driver-hint", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('.driver-hint').click()")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.45) # settle (fix #2)
  capture_frames(app, dir, ctr, duration_ms = 1250) # "Beacon 1" popover: hold

  pulse_cursor(app, ".driver-popover-next-btn", pulse = TRUE)
  capture_frames(app, dir, ctr, duration_ms = 70, interval_ms = 70) # pulse-visible frame
  app$run_js("document.querySelector('.driver-popover-next-btn').click()")
  capture_frames(app, dir, ctr, duration_ms = 900) # dismissed, hold (bumped per #10)

  remove_cursor(app)
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
#
# Captured at `scale = 2` (chromote's `screenshot(scale = )`, which sets
# `Page.captureScreenshot`'s clip.scale -- a sharper capture of the same
# CSS-pixel region, independent of any device-scale-factor emulation).
#
# Each panel's crop is the union bounding box of `.card` (the tab card
# being toured), `.driver-popover`, and `.driver-popover-arrow` -- not just
# the popover alone (media-ux-review.md #7/section 4): the arrow's own
# rect extends outside `.driver-popover`'s box model (confirmed: it sits
# ~10px above the popover's own top when the popover opens below its
# target), so naming it explicitly is what keeps `expand` from having to
# guess which side it's clipped on. This shows the popover in the app's own
# product context instead of floating alone on a blank background.
record_theme <- function() {
  app <- new_app(); on.exit(app$stop(), add = TRUE)
  dir <- new_frame_dir()
  panel_selector <- c(".card", ".driver-popover", ".driver-popover-arrow")
  shot_args <- list(scale = 2, expand = 16)

  app$run_js(FORCE_LIGHT_JS)
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.6)
  left <- file.path(dir, "default.png")
  app$get_screenshot(left, selector = panel_selector, screenshot_args = shot_args)

  app$run_js("document.querySelector('.driver-popover-close-btn').click()")
  app$wait_for_js("document.querySelector('.driver-popover') === null")

  app$set_inputs(theme_bootstrap = TRUE)
  app$run_js(FORCE_DARK_JS)
  Sys.sleep(0.3)
  app$click("btn_start")
  app$wait_for_js("document.querySelector('.driver-popover') !== null")
  Sys.sleep(0.6)
  right <- file.path(dir, "bootstrap-dark.png")
  app$get_screenshot(right, selector = panel_selector, screenshot_args = shot_args)

  # hstack requires equal input heights; the two crops differ by a few px
  # (theme changes affect box-model rounding), so scale both to the
  # taller one's height first, preserving aspect ratio. A solid-color
  # gutter between them (sized so it reads as ~16px once the combined
  # image is scaled to 900px wide) keeps the two panels visually distinct
  # rather than merged into one image, then the combined image (panels +
  # gutter) is scaled so the pair together is ~900px wide.
  target_h <- max(image_height(left), image_height(right))
  w_l <- image_width(left) * target_h / image_height(left)
  w_r <- image_width(right) * target_h / image_height(right)
  approx_scale <- 900 / (w_l + w_r)
  gutter_px <- max(2L, round(16 / approx_scale))

  # `-frames:v 1`: the synthetic lavfi color source (the gutter) is an
  # infinite-duration generator, unlike the two single-frame PNG inputs, so
  # the image2 muxer needs telling explicitly to stop after one frame.
  out <- file.path(FIG_DIR, "theme.png")
  run_ffmpeg(c(
    "-y", "-i", left, "-i", right,
    "-f", "lavfi", "-i", sprintf("color=c=white:s=%dx%d", gutter_px, target_h),
    "-filter_complex", sprintf(
      "[0:v]scale=-1:%d:flags=lanczos[a];[1:v]scale=-1:%d:flags=lanczos[b];[a][2:v][b]hstack=inputs=3[s];[s]scale=900:-1:flags=lanczos",
      target_h, target_h
    ),
    "-frames:v", "1",
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
