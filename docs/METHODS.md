# Methods and estimands

This repository generalizes the reusable model structure found in the working-folder biomarker workflows. Trial identifiers, source paths, proprietary data, and study-specific conclusions are intentionally excluded.

## Estimand matrix

| Model | Population | Variable | Comparison or association | Summary measure | Primary checks |
|---|---|---|---|---|---|
| MMRM | Configured analysis population | Longitudinal continuous biomarker | Active minus control at each visit | Adjusted mean difference | Unique subject/visit rows, covariance fit, warnings, contrast direction |
| Binomial GLMM | Configured analysis population | Repeated binary response and standardized biomarker | Within-control biomarker association and treatment-by-biomarker interaction | Log odds and odds ratio | Events/non-events per treatment/visit cell, convergence, singularity, extreme coefficients, CI width |

The MMRM uses baseline, treatment, categorical visit, and treatment-by-visit fixed effects. It uses an unstructured within-subject correlation and visit-specific residual variances through `nlme::gls`.

The GLMM uses a subject random intercept through `lme4::glmer`. The `value_z` main effect is the biomarker association in the reference arm. Its treatment interaction is the differential association; it is not interchangeable with an arm-specific odds ratio.

Both models are reference implementations. The protocol, SAP, population flags, intercurrent-event strategy, covariance choice, degrees-of-freedom method, and multiplicity policy must be approved before confirmatory use.
