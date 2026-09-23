from __future__ import annotations

import csv
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "data" / "synthetic_biomarkers.csv"
REQUIRED = {
    "subject_id",
    "treatment",
    "visit",
    "biomarker",
    "baseline",
    "value",
    "response",
    "analysis_population",
}


class ContractTest(unittest.TestCase):
    def read_rows(self, path: Path) -> list[dict[str, str]]:
        with path.open(encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle))

    def test_fixture_schema_and_model_cells(self) -> None:
        rows = self.read_rows(FIXTURE)
        self.assertEqual(set(rows[0]), REQUIRED)
        self.assertEqual(len(rows), 48 * 3 * 2)
        keys = {(row["subject_id"], row["visit"], row["biomarker"]) for row in rows}
        self.assertEqual(len(keys), len(rows))
        self.assertEqual({row["treatment"] for row in rows}, {"Control", "Active"})
        self.assertEqual({row["response"] for row in rows}, {"0", "1"})
        for treatment in ("Control", "Active"):
            for visit in ("Week 4", "Week 8", "Week 12"):
                outcomes = {
                    row["response"]
                    for row in rows
                    if row["treatment"] == treatment and row["visit"] == visit
                }
                self.assertEqual(outcomes, {"0", "1"})

    def test_fixture_is_reproducible(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            generated = Path(directory) / "fixture.csv"
            subprocess.run(
                [sys.executable, str(ROOT / "tools" / "generate_synthetic_data.py"), "--output", str(generated)],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual(generated.read_bytes(), FIXTURE.read_bytes())


if __name__ == "__main__":
    unittest.main()
