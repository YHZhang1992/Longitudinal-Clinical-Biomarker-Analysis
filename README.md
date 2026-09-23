# Longitudinal Clinical Biomarker Analysis

A standardized reference workflow for longitudinal continuous biomarkers and repeated binary responder endpoints. It combines:

- MMRM-style continuous modeling with baseline adjustment, categorical visits, treatment-by-visit effects, unstructured within-subject correlation, and visit-specific residual variances.
- Binomial GLMM modeling with subject random intercepts, standardized biomarker values, and an explicit treatment-by-biomarker interaction.
- Complete, core, supportive, and QC-review reporting layers with provenance and attrition outputs.

The repository was distilled from reusable code in the local analysis collection. It contains synthetic data only; trial-specific source files and conclusions are not included.

## Quick start

Requirements: Python 3.11+ for the data-contract test and R 4.3+ with `nlme` and `lme4` for model execution.

```bash
python -m unittest discover -s tests -p "test_*.py" -v
Rscript tests/test_models.R
Rscript scripts/run_analysis.R \
  --input data/synthetic_biomarkers.csv \
  --config config/analysis.R \
  --output output
```

## Input contract

The default long-format input contains `subject_id`, `treatment`, `visit`, `biomarker`, `baseline`, `value`, `response`, and `analysis_population`. Each subject/visit/biomarker key must be unique. Responses must be 0/1 or missing.

## Repository layout

- `R/` contains validation, model, QC, and reporting functions.
- `config/analysis.R` freezes factor order, formulas, thresholds, and reporting rules.
- `data/` contains a deterministic synthetic fixture.
- `scripts/run_analysis.R` runs the complete workflow.
- `tests/` checks both the portable contract and the R models.
- `docs/` records estimands, output rules, and trial-adaptation controls.

## Interpretation boundary

This is an educational and development reference, not confirmatory sign-off. A successful model fit is not automatically interpretable. Sparse outcome cells, separation, singularity, convergence warnings, extreme coefficients, and wide intervals are routed to QC review. Production use requires the raw data, protocol/SAP, a qualified environment, and independent validation.
