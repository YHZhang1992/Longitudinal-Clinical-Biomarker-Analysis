#!/usr/bin/env python3
"""Generate the deterministic, non-clinical fixture used by this repository."""

from __future__ import annotations

import argparse
import csv
import math
import random
from pathlib import Path


def generate_rows(seed: int = 20260923) -> list[dict[str, object]]:
    rng = random.Random(seed)
    visits = (("Week 4", 1), ("Week 8", 2), ("Week 12", 3))
    biomarkers = ("Marker_A", "Marker_B")
    rows: list[dict[str, object]] = []
    for subject_number in range(1, 49):
        subject = f"S{subject_number:03d}"
        treatment = "Active" if subject_number % 2 == 0 else "Control"
        subject_effect = rng.gauss(0, 0.45)
        baselines = {"Marker_A": 5.0 + rng.gauss(0, 0.65), "Marker_B": 8.0 + rng.gauss(0, 0.8)}
        latent_by_visit: dict[str, tuple[float, int]] = {}
        for visit, visit_index in visits:
            marker_a = baselines["Marker_A"] + subject_effect + 0.12 * visit_index
            if treatment == "Active":
                marker_a += 0.45 * visit_index
            marker_a += rng.gauss(0, 0.35)
            linear = -0.8 + 0.55 * (marker_a - 5.0) + 0.25 * (treatment == "Active") + 0.12 * visit_index
            probability = 1.0 / (1.0 + math.exp(-linear))
            latent_by_visit[visit] = (marker_a, int(rng.random() < probability))
        for visit, visit_index in visits:
            for biomarker in biomarkers:
                if biomarker == "Marker_A":
                    value = latent_by_visit[visit][0]
                else:
                    value = baselines[biomarker] + 0.5 * subject_effect - 0.08 * visit_index
                    if treatment == "Active":
                        value += 0.2 * visit_index
                    value += rng.gauss(0, 0.5)
                rows.append(
                    {
                        "subject_id": subject,
                        "treatment": treatment,
                        "visit": visit,
                        "biomarker": biomarker,
                        "baseline": f"{baselines[biomarker]:.6f}",
                        "value": f"{value:.6f}",
                        "response": latent_by_visit[visit][1],
                        "analysis_population": 1,
                    }
                )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("data/synthetic_biomarkers.csv"))
    args = parser.parse_args()
    rows = generate_rows()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} synthetic rows to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
