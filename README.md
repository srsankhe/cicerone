<img src="./man/figures/logo.png" align = "right" height=250/>

# cicerone

<!-- badges: start -->
[![R-CMD-check](https://github.com/srsankhe/cicerone/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/srsankhe/cicerone/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/srsankhe/cicerone/branch/main/graph/badge.svg)](https://app.codecov.io/gh/srsankhe/cicerone/tree/main)
[![Version](https://img.shields.io/github/r-package/v/srsankhe/cicerone?label=version)](https://github.com/srsankhe/cicerone/blob/main/DESCRIPTION)
[![CRAN status](https://www.r-pkg.org/badges/version/cicerone)](https://CRAN.R-project.org/package=cicerone)
[![Lifecycle: stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/srsankhe/cicerone/blob/main/LICENSE.md)
<!-- badges: end -->

A convenient API to create guided tours of Shiny applications using [driver.js](https://driverjs.com/).

> **Note:** this is a fork of [JohnCoene/cicerone](https://github.com/JohnCoene/cicerone)
> (archived January 2025). Version 2.0.0 upgrades the bundled driver.js
> from 0.9.8 to **1.8.0** — a complete rewrite of the underlying library —
> while keeping the original cicerone API backwards compatible. See
> `NEWS.md` for the full list of changes and new capabilities.

## Usage

Let's create a very basic Shiny app to demonstrate: it takes a text input and on hitting a button simply prints it.

```r
library(shiny)

ui <- fluidPage(
  textInput("text_inputId", "Enter some text"),
  actionButton("submit_inputId", "Submit text"),
  verbatimTextOutput("print")
)

server <- function(input, output){
  txt <- eventReactive(input$submit_inputId, {
    input$text_inputId
  })

  output$print <- renderPrint(txt())
}

shinyApp(ui, server)
```

Now we can create a guide to walk the user through the application: simply initialise a new guide from the `Cicerone` object then add `steps`.

```r
library(cicerone)

guide <- Cicerone$
  new(
    show_progress = TRUE # driver.js 1.x: "1 of 2" in the popover
  )$
  step(
    el = "text_inputId",
    title = "Text Input",
    description = "This is where you enter the text you want to print."
  )$
  step(
    "submit_inputId",
    "Send the Text",
    "Send the text to the server for printing"
  )
```

This is our guide created, we can now include it the Shiny app we created earlier and start the guide. Note that you need to include `use_cicerone` in your UI.

```r
library(shiny)

ui <- fluidPage(
  use_cicerone(), # include dependencies
  textInput("text_inputId", "Enter some text"),
  actionButton("submit_inputId", "Submit text"),
  verbatimTextOutput("print")
)

server <- function(input, output){

  # initialise then start the guide
  guide$init()$start()

  txt <- eventReactive(input$submit_inputId, {
    input$text_inputId
  })

  output$print <- renderPrint(txt())
}

shinyApp(ui, server)
```

![](./man/figures/demo.gif)

All options are detailed in the documentation of the object: `?Cicerone`.

## Hints

Version 2.0.0 also wraps the driver.js **hints** module: pulsing beacons
attached to elements that open a popover when clicked.

```r
hints <- Hints$
  new(button_text = "Got it")$
  hint(
    el = "text_inputId",
    title = "Pssst",
    description = "You can type here.",
    hint_id = "typing-hint"
  )

# in the server
hints$init()$show()
```

Hints can be controlled from the server with `open()`, `close()`,
`dismiss()`, and `restore()`, and fire the Shiny inputs
`{id}_cicerone_hint_opened`, `{id}_cicerone_hint_dismissed`, and
`{id}_cicerone_hint_button`.

## New in 2.0.0 (driver.js 1.x)

- Progress text (`show_progress`, `progress_text`)
- Overlay styling (`overlay_color`, `overlay_opacity`) and behavior
  (`overlay_click_behavior`)
- Cutout styling (`stage_padding`, `stage_radius`) and smooth scrolling
  (`smooth_scroll`)
- Element-less "modal" steps (only `title`/`description`)
- Robustness options: `skip_missing_element`, `wait_for_element`
- Interaction options: `disable_active_interaction`, `advance_on_click`
- Rich lifecycle hooks on tours and steps (`on_deselected`,
  `on_popover_render`, `on_destroyed`, ...)
- `move_to()`, `refresh()`, `get_state()` methods and a
  `{id}_cicerone_state` Shiny input updated on every highlight
- The `Hints` class

## Installation

Install this fork from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("<your-github-username>/cicerone")
```

The archived 1.x version remains on [CRAN](https://CRAN.R-project.org/package=cicerone).

## Development

The JavaScript sources live in `srcjs/` and are bundled to
`inst/packer/cicerone.js` with webpack:

```sh
npm install
npm run production
```

After changing the R documentation, regenerate the `man/` pages with
`devtools::document()`.
