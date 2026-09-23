prepare_biomarker_data <- function(data, config) {
  column_map <- unlist(config$columns, use.names = TRUE)
  required <- c(unname(column_map), config$population$column)
  assert_columns(data, required)

  keep <- as.character(data[[config$population$column]]) == as.character(config$population$value)
  analysis <- data[!is.na(keep) & keep, required, drop = FALSE]
  names(analysis)[match(unname(column_map), names(analysis))] <- names(column_map)
  if (!nrow(analysis)) stop("No records remain after applying the analysis population.", call. = FALSE)
  if (anyNA(analysis[c("subject", "treatment", "visit", "biomarker")])) {
    stop("Subject, treatment, visit, and biomarker identifiers cannot be missing.", call. = FALSE)
  }
  key <- analysis[c("subject", "visit", "biomarker")]
  if (anyDuplicated(key)) stop("Expected one record per subject, visit, and biomarker.", call. = FALSE)

  analysis$treatment <- factor(analysis$treatment, levels = config$treatment_levels)
  analysis$visit <- factor(analysis$visit, levels = config$visit_levels)
  if (anyNA(analysis$treatment)) stop("Input contains a treatment not declared in treatment_levels.", call. = FALSE)
  if (anyNA(analysis$visit)) stop("Input contains a visit not declared in visit_levels.", call. = FALSE)
  for (column in c("baseline", "value", "response")) analysis[[column]] <- suppressWarnings(as.numeric(analysis[[column]]))
  nonmissing_response <- stats::na.omit(analysis$response)
  if (!all(nonmissing_response %in% c(0, 1))) stop("Response must be coded 0/1 or missing.", call. = FALSE)
  analysis$.visit_order <- match(analysis$visit, config$visit_levels)
  analysis
}

mmrm_failure_rows <- function(biomarker, config, n_observations, n_subjects, message) {
  data.frame(
    model = "MMRM", biomarker = biomarker, question = "active versus control by visit",
    endpoint = biomarker, visit = config$visit_levels, term = "treatment contrast",
    contrast = paste(config$treatment_levels[2], "minus", config$treatment_levels[1]),
    population = config$population$value, n_observations = n_observations, n_subjects = n_subjects,
    events = NA_integer_, non_events = NA_integer_, effect_scale = "mean difference",
    estimate = NA_real_, standard_error = NA_real_, confidence_lower = NA_real_, confidence_upper = NA_real_,
    p_value = NA_real_, q_value = NA_real_, multiplicity_family = "mmrm_treatment_by_visit",
    formula = config$mmrm$formula, model_status = "failed", warnings = message,
    stringsAsFactors = FALSE
  )
}

fit_mmrm_biomarker <- function(data, biomarker, config) {
  current <- data[data$biomarker == biomarker, , drop = FALSE]
  model_data <- current[stats::complete.cases(current[c("subject", "treatment", "visit", "baseline", "value")]), , drop = FALSE]
  n_subjects <- length(unique(model_data$subject))
  formula <- value ~ baseline + treatment * visit
  if (n_subjects < 4L || nlevels(droplevels(model_data$treatment)) < 2L || nlevels(droplevels(model_data$visit)) < 2L) {
    message <- "Insufficient subjects, treatments, or visits for MMRM."
    return(list(results = mmrm_failure_rows(biomarker, config, nrow(model_data), n_subjects, message),
                qc = data.frame(model = "MMRM", biomarker = biomarker, status = "failed", n_observations = nrow(model_data), n_subjects = n_subjects, events = NA_integer_, non_events = NA_integer_, sparse_cells = NA, singular = NA, convergence = "not fitted", warnings = message, formula = config$mmrm$formula)))
  }

  fit_attempt <- capture_conditions(nlme::gls(
    formula,
    data = model_data,
    correlation = nlme::corSymm(form = ~ .visit_order | subject),
    weights = nlme::varIdent(form = ~ 1 | visit),
    method = config$mmrm$method,
    na.action = na.exclude,
    control = nlme::glsControl(msMaxIter = 200, returnObject = FALSE)
  ))
  if (is_captured_error(fit_attempt$value)) {
    message <- collapse_messages(c(fit_attempt$warnings, fit_attempt$value$message))
    return(list(results = mmrm_failure_rows(biomarker, config, nrow(model_data), n_subjects, message),
                qc = data.frame(model = "MMRM", biomarker = biomarker, status = "failed", n_observations = nrow(model_data), n_subjects = n_subjects, events = NA_integer_, non_events = NA_integer_, sparse_cells = NA, singular = NA, convergence = "failed", warnings = message, formula = config$mmrm$formula)))
  }

  fit <- fit_attempt$value
  coefficients <- stats::coef(fit)
  covariance <- stats::vcov(fit)
  baseline_reference <- mean(model_data$baseline, na.rm = TRUE)
  reference <- config$treatment_levels[1]
  active <- config$treatment_levels[2]
  design_terms <- stats::delete.response(stats::terms(fit))
  status <- if (length(fit_attempt$warnings)) "review" else "pass"
  results <- lapply(config$visit_levels, function(visit_name) {
    reference_row <- data.frame(baseline = baseline_reference, treatment = factor(reference, levels = config$treatment_levels), visit = factor(visit_name, levels = config$visit_levels))
    active_row <- data.frame(baseline = baseline_reference, treatment = factor(active, levels = config$treatment_levels), visit = factor(visit_name, levels = config$visit_levels))
    x_reference <- stats::model.matrix(design_terms, reference_row)
    x_active <- stats::model.matrix(design_terms, active_row)
    contrast <- setNames(rep(0, length(coefficients)), names(coefficients))
    raw_contrast <- x_active[1, ] - x_reference[1, ]
    contrast[intersect(names(contrast), names(raw_contrast))] <- raw_contrast[intersect(names(contrast), names(raw_contrast))]
    estimate <- sum(contrast * coefficients)
    standard_error <- sqrt(drop(t(contrast) %*% covariance %*% contrast))
    degrees_freedom <- max(1, nrow(model_data) - length(coefficients))
    statistic <- estimate / standard_error
    p_value <- 2 * stats::pt(-abs(statistic), df = degrees_freedom)
    critical <- stats::qt(0.975, df = degrees_freedom)
    data.frame(
      model = "MMRM", biomarker = biomarker, question = "active versus control by visit",
      endpoint = biomarker, visit = visit_name, term = "treatment contrast",
      contrast = paste(active, "minus", reference), population = config$population$value,
      n_observations = nrow(model_data), n_subjects = n_subjects, events = NA_integer_, non_events = NA_integer_,
      effect_scale = "mean difference", estimate = estimate, standard_error = standard_error,
      confidence_lower = estimate - critical * standard_error, confidence_upper = estimate + critical * standard_error,
      p_value = p_value, q_value = NA_real_, multiplicity_family = "mmrm_treatment_by_visit",
      formula = config$mmrm$formula, model_status = status, warnings = collapse_messages(fit_attempt$warnings),
      stringsAsFactors = FALSE
    )
  })
  list(
    results = do.call(rbind, results),
    qc = data.frame(model = "MMRM", biomarker = biomarker, status = status, n_observations = nrow(model_data), n_subjects = n_subjects, events = NA_integer_, non_events = NA_integer_, sparse_cells = NA, singular = FALSE, convergence = "completed", warnings = collapse_messages(fit_attempt$warnings), formula = config$mmrm$formula)
  )
}

glmm_failure_row <- function(biomarker, config, n_observations, n_subjects, events, non_events, message) {
  data.frame(
    model = "GLMM", biomarker = biomarker, question = "within-arm biomarker association and treatment interaction",
    endpoint = "binary response", visit = "all", term = "(model fit)", contrast = "not estimable",
    population = config$population$value, n_observations = n_observations, n_subjects = n_subjects,
    events = events, non_events = non_events, effect_scale = "log odds", estimate = NA_real_,
    standard_error = NA_real_, confidence_lower = NA_real_, confidence_upper = NA_real_, p_value = NA_real_, q_value = NA_real_,
    multiplicity_family = "glmm_biomarker_association", formula = config$glmm$formula,
    model_status = "failed", warnings = message, stringsAsFactors = FALSE
  )
}

fit_glmm_biomarker <- function(data, biomarker, config) {
  current <- data[data$biomarker == biomarker, , drop = FALSE]
  model_data <- current[stats::complete.cases(current[c("subject", "treatment", "visit", "value", "response")]), , drop = FALSE]
  n_subjects <- length(unique(model_data$subject))
  events <- sum(model_data$response == 1)
  non_events <- sum(model_data$response == 0)
  value_sd <- stats::sd(model_data$value)
  counts <- table(model_data$treatment, model_data$visit, factor(model_data$response, levels = c(0, 1)))
  sparse <- !length(counts) || min(counts) < config$glmm$min_events_and_nonevents_per_cell
  if (n_subjects < 4L || events == 0L || non_events == 0L || !is.finite(value_sd) || value_sd == 0) {
    message <- "Insufficient subjects, outcome classes, or biomarker variation for GLMM."
    return(list(results = glmm_failure_row(biomarker, config, nrow(model_data), n_subjects, events, non_events, message),
                qc = data.frame(model = "GLMM", biomarker = biomarker, status = "failed", n_observations = nrow(model_data), n_subjects = n_subjects, events = events, non_events = non_events, sparse_cells = sparse, singular = NA, convergence = "not fitted", warnings = message, formula = config$glmm$formula)))
  }
  model_data$value_z <- as.numeric(scale(model_data$value))
  fit_attempt <- capture_conditions(lme4::glmer(
    response ~ value_z * treatment + visit + (1 | subject),
    data = model_data,
    family = stats::binomial(),
    control = lme4::glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 200000))
  ))
  if (is_captured_error(fit_attempt$value)) {
    message <- collapse_messages(c(fit_attempt$warnings, fit_attempt$value$message))
    return(list(results = glmm_failure_row(biomarker, config, nrow(model_data), n_subjects, events, non_events, message),
                qc = data.frame(model = "GLMM", biomarker = biomarker, status = "failed", n_observations = nrow(model_data), n_subjects = n_subjects, events = events, non_events = non_events, sparse_cells = sparse, singular = NA, convergence = "failed", warnings = message, formula = config$glmm$formula)))
  }

  fit <- fit_attempt$value
  coefficient_table <- stats::coef(summary(fit))
  convergence_messages <- fit@optinfo$conv$lme4$messages
  singular <- lme4::isSingular(fit, tol = 1e-4)
  confidence_lower <- coefficient_table[, "Estimate"] - 1.96 * coefficient_table[, "Std. Error"]
  confidence_upper <- coefficient_table[, "Estimate"] + 1.96 * coefficient_table[, "Std. Error"]
  extreme <- any(abs(coefficient_table[, "Estimate"]) > config$glmm$extreme_log_odds)
  wide <- any((confidence_upper - confidence_lower) > config$glmm$maximum_ci_width)
  messages <- collapse_messages(c(fit_attempt$warnings, convergence_messages))
  status <- if (sparse || singular || length(convergence_messages) || length(fit_attempt$warnings) || extreme || wide) "review" else "pass"
  treatment_interaction <- paste0("value_z:treatment", config$treatment_levels[2])
  if (!(treatment_interaction %in% rownames(coefficient_table))) {
    alternative <- paste0("treatment", config$treatment_levels[2], ":value_z")
    if (alternative %in% rownames(coefficient_table)) treatment_interaction <- alternative
  }
  results <- data.frame(
    model = "GLMM", biomarker = biomarker, question = "within-arm biomarker association and treatment interaction",
    endpoint = "binary response", visit = "all", term = rownames(coefficient_table),
    contrast = ifelse(rownames(coefficient_table) == "value_z", paste("within", config$treatment_levels[1], "association"), ifelse(rownames(coefficient_table) == treatment_interaction, "treatment-by-biomarker interaction", "model coefficient")),
    population = config$population$value, n_observations = nrow(model_data), n_subjects = n_subjects,
    events = events, non_events = non_events, effect_scale = "log odds",
    estimate = coefficient_table[, "Estimate"], standard_error = coefficient_table[, "Std. Error"],
    confidence_lower = confidence_lower, confidence_upper = confidence_upper,
    p_value = coefficient_table[, "Pr(>|z|)"], q_value = NA_real_,
    multiplicity_family = ifelse(grepl("value_z", rownames(coefficient_table), fixed = TRUE), "glmm_biomarker_association", "not adjusted"),
    formula = config$glmm$formula, model_status = status, warnings = messages,
    stringsAsFactors = FALSE, row.names = NULL
  )
  list(
    results = results,
    qc = data.frame(model = "GLMM", biomarker = biomarker, status = status, n_observations = nrow(model_data), n_subjects = n_subjects, events = events, non_events = non_events, sparse_cells = sparse, singular = singular, convergence = if (length(convergence_messages)) "review" else "completed", warnings = messages, formula = config$glmm$formula)
  )
}

apply_reporting_tiers <- function(results, config) {
  for (family_name in unique(results$multiplicity_family)) {
    if (family_name == "not adjusted") next
    indices <- which(results$multiplicity_family == family_name & is.finite(results$p_value))
    if (length(indices)) results$q_value[indices] <- stats::p.adjust(results$p_value[indices], method = config$reporting$adjustment_method)
  }
  results$reporting_tier <- "not_selected"
  results$reporting_tier[results$model_status != "pass"] <- "qc_review"
  core <- results$model_status == "pass" & is.finite(results$q_value) & results$q_value <= config$reporting$adjusted_threshold
  supportive <- results$model_status == "pass" & !core & is.finite(results$p_value) & results$p_value <= config$reporting$nominal_threshold
  results$reporting_tier[core] <- "core"
  results$reporting_tier[supportive] <- "supportive"
  results
}
