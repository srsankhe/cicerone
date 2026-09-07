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
#'   \item{`font_family`}{Sets `--driver-popover-font-family` directly --
#'   driver.js's own custom property, not a `--cicerone-*` one. driver.js
#'   already declares `.driver-popover`'s `font-family` from this
#'   variable (with its own font stack as the `var()` fallback), so
#'   there is no separate `--cicerone-font-family` to alias.}
#'   \item{`title_size`}{`--cicerone-title-size`: title font size.}
#'   \item{`title_weight`}{`--cicerone-title-weight`: title font weight.}
#'   \item{`line_height`}{`--cicerone-line-height`: description line
#'   height.}
#'   \item{`btn_font_size`}{`--cicerone-btn-font-size`: footer button
#'   font size.}
#'   \item{`btn_border`}{`--cicerone-btn-border`: footer button border
#'   (a full shorthand value, e.g. `"1px solid #ccc"`).}
#'   \item{`btn_radius`}{`--cicerone-btn-radius`: footer button corner
#'   radius (independent of `radius`, which is the popover shell only).}
#'   \item{`btn_hover_bg`}{`--cicerone-btn-hover-bg`: footer button
#'   background on hover/focus. One value for every footer button; there
#'   is no separate hover color for Next vs. Previous/Close.}
#'   \item{`max_width`}{`--cicerone-max-width`: popover max width.}
#' }
#'
#' @param surface,text,muted,accent,radius,font_size,shadow,btn_bg,btn_text,progress_fg,progress_bg,title_size,title_weight,line_height,btn_font_size,btn_border,btn_radius,btn_hover_bg,max_width
#' CSS values for the corresponding custom property, e.g.:
#' `accent = "#ff0000"`, `radius = "10px"`. `NULL` (the default) leaves
#' that property unset.
#' @param font_family CSS `font-family` value, e.g.
#' `"Georgia, serif"`. Sets driver.js's own `--driver-popover-font-family`
#' (see the CSS custom properties section below) rather than a
#' `--cicerone-*` property. `NULL` (the default) leaves it unset.
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
#' same token Bootstrap's own `.progress` track uses); `font_family` maps
#' to `--bs-body-font-family` (so the popover inherits the app's own
#' font); `line_height` maps to `--bs-body-line-height`; `btn_font_size`
#' maps to `--bs-body-font-size` (Bootstrap's own `--bs-btn-font-size` is
#' only declared inside `.btn`, not at the root, so this is the closest
#' root-scoped token); `btn_border` maps to
#' `var(--bs-border-width) solid var(--bs-border-color)`; `btn_radius`
#' maps to `--bs-border-radius` (the same token `.btn`'s own default
#' resolves to); `btn_hover_bg` maps to `--bs-tertiary-bg` (the closest
#' root-scoped "subtle surface" token; `--bs-btn-hover-bg` is
#' component-scoped only). `title_size`, `title_weight` and `max_width`
#' have no Bootstrap equivalent and are left unset by the preset --
#' driver.js's own defaults stand unless you pass them explicitly.
#' Explicit arguments override the preset's value for that one property.
#'
#' @return An [htmltools::tags] `<style>` element.
#'
#' @examples
#' library(shiny)
#'
#' ui <- fluidPage(
#'   use_cicerone(),
#'   cicerone_theme(accent = "#ff0000", radius = "10px"),
#'   cicerone_theme(
#'     font_family = "Georgia, serif", title_size = "24px",
#'     btn_border = "2px solid #ff0000", selector = ".my-tour"
#'   )
#' )
#'
#' @export
cicerone_theme <- function(surface = NULL, text = NULL, muted = NULL,
  accent = NULL, radius = NULL, font_size = NULL, shadow = NULL,
  btn_bg = NULL, btn_text = NULL, progress_fg = NULL, progress_bg = NULL,
  font_family = NULL, title_size = NULL, title_weight = NULL,
  line_height = NULL, btn_font_size = NULL, btn_border = NULL,
  btn_radius = NULL, btn_hover_bg = NULL, max_width = NULL,
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
      progress_bg = "var(--bs-secondary-bg)",
      font_family = "var(--bs-body-font-family)",
      line_height = "var(--bs-body-line-height)",
      btn_font_size = "var(--bs-body-font-size)",
      btn_border = "var(--bs-border-width) solid var(--bs-border-color)",
      btn_radius = "var(--bs-border-radius)",
      btn_hover_bg = "var(--bs-tertiary-bg)"
      # title_size, title_weight, max_width: no root-scoped Bootstrap
      # token exists for these -- left unset so driver.js's own default
      # stands (see @details above).
    )
  } else {
    list()
  }

  # explicit arguments always win over the preset
  supplied <- drop_nulls(list(
    surface = surface, text = text, muted = muted, accent = accent,
    radius = radius, font_size = font_size, shadow = shadow,
    btn_bg = btn_bg, btn_text = btn_text, progress_fg = progress_fg,
    progress_bg = progress_bg, font_family = font_family,
    title_size = title_size, title_weight = title_weight,
    line_height = line_height, btn_font_size = btn_font_size,
    btn_border = btn_border, btn_radius = btn_radius,
    btn_hover_bg = btn_hover_bg, max_width = max_width
  ))
  values <- utils::modifyList(values, supplied)

  if (!length(values))
    return(htmltools::tags$style())

  # `font_family` is the one argument that sets driver.js's own custom
  # property (--driver-popover-font-family) instead of a --cicerone-*
  # one -- see the CSS custom properties section above.
  css_var_name <- function(nm) {
    if (identical(nm, "font_family")) return("--driver-popover-font-family")
    paste0("--cicerone-", gsub("_", "-", nm, fixed = TRUE))
  }

  props <- vapply(
    names(values),
    function(nm) sprintf("%s: %s;", css_var_name(nm), values[[nm]]),
    character(1)
  )

  htmltools::tags$style(
    sprintf("%s {\n  %s\n}", selector, paste(props, collapse = "\n  "))
  )
}
