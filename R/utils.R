assert_columns <- function(data, columns) {
  missing <- setdiff(columns, names(data))
  if (length(missing)) {
    stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
}

load_analysis_config <- function(path) {
  environment <- new.env(parent = baseenv())
  sys.source(path, envir = environment)
  if (!exists("config", envir = environment, inherits = FALSE)) {
    stop("Configuration file must define an object named 'config'.", call. = FALSE)
  }
  config <- get("config", envir = environment, inherits = FALSE)
  required <- c("analysis_id", "population", "columns", "treatment_levels", "visit_levels", "mmrm", "glmm", "reporting")
  missing <- setdiff(required, names(config))
  if (length(missing)) stop(sprintf("Configuration is missing: %s", paste(missing, collapse = ", ")), call. = FALSE)
  if (length(config$treatment_levels) != 2L) stop("Exactly two ordered treatment levels are required.", call. = FALSE)
  config
}

capture_conditions <- function(expression) {
  warnings <- character()
  value <- tryCatch(
    withCallingHandlers(
      expression,
      warning = function(condition) {
        warnings <<- c(warnings, conditionMessage(condition))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(condition) structure(list(message = conditionMessage(condition)), class = "captured_error")
  )
  list(value = value, warnings = unique(warnings))
}

is_captured_error <- function(value) inherits(value, "captured_error")

collapse_messages <- function(messages) {
  messages <- unique(messages[nzchar(messages)])
  if (length(messages)) paste(messages, collapse = " | ") else ""
}

empty_number <- function() NA_real_

write_table <- function(data, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "")
}

sha256_file <- function(path) {
  command <- Sys.which("sha256sum")
  if (nzchar(command)) return(strsplit(system2(command, shQuote(path), stdout = TRUE), "[[:space:]]+")[[1]][1])
  unname(tools::md5sum(path))
}

utc_now <- function() format(Sys.time(), tz = "UTC", usetz = TRUE)
