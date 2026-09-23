# Adaptation checklist

1. Create a new configuration and retain the validated synthetic example.
2. Map source columns and verify treatment, visit, biomarker, and population values.
3. Document the population, endpoint, intercurrent-event strategy, contrast, summary measure, and sensitivity estimator from the protocol/SAP.
4. Confirm units, transformations, assay namespaces, BQL rules, and duplicate handling before modeling.
5. Define treatment order and every visit explicitly; never rely on lexical factor ordering.
6. Review row and subject attrition before fitting models.
7. Review event and non-event counts in every treatment-by-visit cell.
8. Verify formula, contrast sign, standardization population, covariance structure, and missing-at-random assumption.
9. Inspect every non-pass model in `model_qc.csv`.
10. Independently validate production results and document the qualified R environment.

Stop for SAP clarification when the population, intercurrent-event strategy, primary time point, contrast, or multiplicity family is unresolved.
