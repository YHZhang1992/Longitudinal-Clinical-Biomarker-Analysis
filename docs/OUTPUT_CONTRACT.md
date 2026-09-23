# Output contract

- `complete_results.csv` retains every attempted estimand, including failed fits.
- `core_results.csv` contains exact QC-pass rows meeting the configured adjusted threshold.
- `supportive_results.csv` contains QC-pass nominal rows that do not meet the adjusted threshold.
- `qc_review_results.csv` contains rows from sparse, singular, warning-producing, unstable, or failed fits.
- `model_qc.csv` records counts, convergence, singularity, sparsity, formula, and warnings.
- `attrition.csv` records row counts at the principal filtering stages.
- `run_manifest.csv` records configuration/input checksums and runtime provenance.

No result should be promoted from QC review by deleting its status. Resolve the underlying model or data issue and rerun the complete workflow.
