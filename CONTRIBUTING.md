# Contributing

Keep changes small, configurable, and traceable. Add or update synthetic tests for every model change. Do not commit study data, participant identifiers, credentials, or generated production results.

Before opening a change:

```bash
python -m unittest discover -s tests -p "test_*.py" -v
Rscript tests/test_models.R
```

Statistical changes must document the estimand, formula, contrast direction, covariance/random-effects structure, QC rules, and expected output changes.
