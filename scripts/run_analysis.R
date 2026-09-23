script_argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- sub("^--file=", "", script_argument[1])
repo_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

source(file.path(repo_root, "R", "utils.R"))
source(file.path(repo_root, "R", "models.R"))
source(file.path(repo_root, "R", "workflow.R"))

arguments <- commandArgs(trailingOnly = TRUE)
argument_value <- function(name, default) {
  index <- match(name, arguments)
  if (is.na(index)) return(default)
  if (index == length(arguments)) stop(sprintf("Missing value after %s", name), call. = FALSE)
  arguments[index + 1]
}

input_path <- argument_value("--input", file.path(repo_root, "data", "synthetic_biomarkers.csv"))
config_path <- argument_value("--config", file.path(repo_root, "config", "analysis.R"))
output_dir <- argument_value("--output", file.path(repo_root, "output"))

result <- run_biomarker_analysis(input_path, config_path, output_dir)
cat(sprintf("Completed %d result rows across %d model fits.\n", nrow(result$results), nrow(result$qc)))
