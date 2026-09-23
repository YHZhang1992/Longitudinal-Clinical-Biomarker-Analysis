script_argument <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_path <- sub("^--file=", "", script_argument[1])
repo_root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)

source(file.path(repo_root, "R", "utils.R"))
source(file.path(repo_root, "R", "models.R"))
source(file.path(repo_root, "R", "workflow.R"))

stopifnot(requireNamespace("nlme", quietly = TRUE))
stopifnot(requireNamespace("lme4", quietly = TRUE))

output_dir <- tempfile("biomarker-analysis-")
result <- run_biomarker_analysis(
  file.path(repo_root, "data", "synthetic_biomarkers.csv"),
  file.path(repo_root, "config", "analysis.R"),
  output_dir
)

expected_files <- c(
  "complete_results.csv", "core_results.csv", "supportive_results.csv",
  "qc_review_results.csv", "model_qc.csv", "attrition.csv", "run_manifest.csv"
)
stopifnot(all(file.exists(file.path(output_dir, expected_files))))
stopifnot(all(c("MMRM", "GLMM") %in% unique(result$results$model)))
stopifnot(all(c("Marker_A", "Marker_B") %in% unique(result$results$biomarker)))
stopifnot(nrow(result$qc) == 4L)
stopifnot(all(result$results$p_value[is.finite(result$results$p_value)] >= 0))
stopifnot(all(result$results$p_value[is.finite(result$results$p_value)] <= 1))
stopifnot(all(result$results$confidence_lower[is.finite(result$results$confidence_lower)] <= result$results$confidence_upper[is.finite(result$results$confidence_upper)]))
cat("Clinical MMRM/GLMM tests passed.\n")
