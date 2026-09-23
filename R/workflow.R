run_biomarker_analysis <- function(input_path, config_path, output_dir) {
  config <- load_analysis_config(config_path)
  raw <- utils::read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)
  analysis <- prepare_biomarker_data(raw, config)
  biomarkers <- sort(unique(analysis$biomarker))

  mmrm <- lapply(biomarkers, function(name) fit_mmrm_biomarker(analysis, name, config))
  glmm <- lapply(biomarkers, function(name) fit_glmm_biomarker(analysis, name, config))
  complete <- do.call(rbind, c(lapply(mmrm, `[[`, "results"), lapply(glmm, `[[`, "results")))
  qc <- do.call(rbind, c(lapply(mmrm, `[[`, "qc"), lapply(glmm, `[[`, "qc")))
  complete <- apply_reporting_tiers(complete, config)

  attrition <- data.frame(
    stage = c("input", "analysis_population", "model_complete_records"),
    records = c(nrow(raw), nrow(analysis), sum(stats::complete.cases(analysis[c("subject", "treatment", "visit", "biomarker", "value")])))
  )
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_table(complete, file.path(output_dir, "complete_results.csv"))
  write_table(complete[complete$reporting_tier == "core", , drop = FALSE], file.path(output_dir, "core_results.csv"))
  write_table(complete[complete$reporting_tier == "supportive", , drop = FALSE], file.path(output_dir, "supportive_results.csv"))
  write_table(complete[complete$reporting_tier == "qc_review", , drop = FALSE], file.path(output_dir, "qc_review_results.csv"))
  write_table(qc, file.path(output_dir, "model_qc.csv"))
  write_table(attrition, file.path(output_dir, "attrition.csv"))
  manifest <- data.frame(
    analysis_id = config$analysis_id,
    run_time_utc = utc_now(),
    r_version = R.version.string,
    input = normalizePath(input_path, mustWork = TRUE),
    input_checksum = sha256_file(input_path),
    config = normalizePath(config_path, mustWork = TRUE),
    config_checksum = sha256_file(config_path),
    biomarkers = length(biomarkers),
    result_rows = nrow(complete),
    stringsAsFactors = FALSE
  )
  write_table(manifest, file.path(output_dir, "run_manifest.csv"))
  invisible(list(results = complete, qc = qc, attrition = attrition, manifest = manifest))
}
