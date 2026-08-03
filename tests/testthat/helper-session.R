# mock Shiny session recording custom messages
make_session <- function() {
  e <- new.env()
  e$msgs <- list()
  e$input <- list()
  e$sendCustomMessage <- function(type, message) {
    e$msgs[[length(e$msgs) + 1]] <- list(type = type, message = message)
  }
  e
}
