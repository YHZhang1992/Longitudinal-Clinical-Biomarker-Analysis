config <- list(
  analysis_id = "synthetic-longitudinal-biomarker-v1",
  population = list(column = "analysis_population", value = "1"),
  columns = list(
    subject = "subject_id",
    treatment = "treatment",
    visit = "visit",
    biomarker = "biomarker",
    baseline = "baseline",
    value = "value",
    response = "response"
  ),
  treatment_levels = c("Control", "Active"),
  visit_levels = c("Week 4", "Week 8", "Week 12"),
  mmrm = list(
    formula = "value ~ baseline + treatment * visit",
    covariance = "unstructured correlation with visit-specific variance",
    method = "REML"
  ),
  glmm = list(
    formula = "response ~ value_z * treatment + visit + (1 | subject_id)",
    family = "binomial",
    min_events_and_nonevents_per_cell = 2,
    extreme_log_odds = 10,
    maximum_ci_width = 20
  ),
  reporting = list(
    adjusted_threshold = 0.05,
    nominal_threshold = 0.05,
    adjustment_method = "BH"
  )
)
