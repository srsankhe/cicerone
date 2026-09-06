#' Theme cicerone popovers
#'
#' Set the CSS custom properties `custom.css` reads for popover styling,
#' without hand-editing CSS. Returns a `<style>` tag to place anywhere in
#' the UI; the rule it emits targets a selector, not one element
#' instance, so a single call covers every popover that selector matches.
#'
#' @section CSS custom properties:
#' Each argument maps to one property, set on `selector` (`.driver-popover`
#' by default). Only supplied arguments are emitted; every other property
#' keeps driver.js's own default look.
#' \describe{
#'   \item{`surface`}{`--cicerone-surface`: popover background, and the
#'   one visible border side of the popover arrow (kept equal to the
#'   surface so the arrow reads as a solid-colour pointer).}
#'   \item{`text`}{`--cicerone-text`: title/description text color.}
#'   \item{`muted`}{`--cicerone-muted`: close button icon color.}
#'   \item{`accent`}{`--cicerone-accent`: Next button background.}
#'   \item{`radius`}{`--cicerone-radius`: popover corner radius.}
#'   \item{`font_size`}{`--cicerone-font-size`: description font size.}
#'   \item{`shadow`}{`--cicerone-shadow`: popover box shadow.}
#'   \item{`btn_bg`}{`--cicerone-btn-bg`: footer button background
#'   (Previous/Close; Next starts from `accent` instead).}
#'   \item{`btn_text`}{`--cicerone-btn-text`: footer button text color.}
#'   \item{`progress_fg`}{`--cicerone-progress-fg`: progress text color,
#'   and the filled portion of a [step()]/[initialise()]
#'   `progress_style = "bar"`/`"dots"`.}
#'   \item{`progress_bg`}{`--cicerone-progress-bg`: the unfilled track of
#'   a `progress_style = "bar"`/`"dots"`.}
#' }
#'
#' @param surface,text,muted,accent,radius,font_size,shadow,btn_bg,btn_text,progress_fg,progress_bg
#' CSS values for the corresponding custom property, e.g.:
#' `accent = "#ff0000"`, `radius = "10px"`. `NULL` (the default) leaves
#' that property unset.
#' @param selector CSS selector to set the properties on, e.g. a
#' `popover_class` passed to [Cicerone]/[initialise()]/[highlight()], to
#' theme one tour only. Defaults to `.driver-popover`: every popover in
#' the app.
#' @param preset A built-in set of defaults to start from. Currently only
#' `"bootstrap"` is supported: it maps every property to the matching
#' bslib/Bootstrap 5.3+ CSS variable (`--bs-*`), so the theme follows the
#' app's bslib theme, including dark mode, automatically. `surface`,
#' `text`, `accent`, `radius`, `font_size` and `shadow` map to the
#' matching semantic Bootstrap token (`--bs-body-bg`, `--bs-body-color`,
#' `--bs-primary`, `--bs-border-radius`, `--bs-body-font-size`,
#' `--bs-box-shadow`); `muted` maps to `--bs-secondary-color`; `btn_bg`
#' and `progress_fg` map to `--bs-primary` (buttons and the filled
#' progress indicator read as the theme's primary color); `btn_text`
#' maps to `--bs-white`; `progress_bg` maps to `--bs-secondary-bg` (the
#' same token Bootstrap's own `.progress` track uses). Explicit arguments
#' override the preset's value for that one property.
#'
#' @return An [htmltools::tags] `<style>` element.
#'
#' @examples
#' library(shiny)
#'
#' ui <- fluidPage(
#'   use_cicerone(),
#'   cicerone_theme(accent = "#ff0000", radius = "10px")
#' )
#'
#' @export
cicerone_theme <- function(surface = NULL, text = NULL, muted = NULL,
  accent = NULL, radius = NULL, font_size = NULL, shadow = NULL,
  btn_bg = NULL, btn_text = NULL, progress_fg = NULL, progress_bg = NULL,
  selector = ".driver-popover", preset = NULL) {

  assertthat::assert_that(
    is.null(preset) || identical(preset, "bootstrap"),
    msg = '`preset` must be NULL or "bootstrap"'
  )

  values <- if (identical(preset, "bootstrap")) {
    list(
      surface = "var(--bs-body-bg)",
      text = "var(--bs-body-color)",
      muted = "var(--bs-secondary-color)",
      accent = "var(--bs-primary)",
      radius = "var(--bs-border-radius)",
      font_size = "var(--bs-body-font-size)",
      shadow = "var(--bs-box-shadow)",
      btn_bg = "var(--bs-primary)",
      btn_text = "var(--bs-white)",
      progress_fg = "var(--bs-primary)",
      progress_bg = "var(--bs-secondary-bg)"
    )
  } else {
    list()
  }

  # explicit arguments always win over the preset
  supplied <- drop_nulls(list(
    surface = surface, text = text, muted = muted, accent = accent,
    radius = radius, font_size = font_size, shadow = shadow,
    btn_bg = btn_bg, btn_text = btn_text, progress_fg = progress_fg,
    progress_bg = progress_bg
  ))
  values <- utils::modifyList(values, supplied)

  if (!length(values))
    return(htmltools::tags$style())

  props <- vapply(
    names(values),
    function(nm) sprintf("--cicerone-%s: %s;", gsub("_", "-", nm, fixed = TRUE), values[[nm]]),
    character(1)
  )

  htmltools::tags$style(
    sprintf("%s {\n  %s\n}", selector, paste(props, collapse = "\n  "))
  )
}
