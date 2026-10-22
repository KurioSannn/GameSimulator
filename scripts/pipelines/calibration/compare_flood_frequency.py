"""Compare the production flood frequency (pinned years) with a multi-year candidate (all observed years).

Writes research/reports/validation/flood_frequency_comparison.md. Production is NOT changed here;
switching requires editing `years` in data/calibration/variable_map.json after review (D-037).

Per region it preserves annual counts, observed years, missing years (never treated as 0) and
completeness = observed years / candidate window.
"""
from __future__ import annotations

import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402
from pipelines.calibration.build_baseline import gamma_poisson_rate  # noqa: E402

OUT = REPO_ROOT / "research/reports/validation/flood_frequency_comparison.md"


def main() -> int:
    vm = json.loads((REPO_ROOT / "data/calibration/variable_map.json").read_text(encoding="utf-8"))
    prod_years = set(vm["rules"]["flood_frequency"].get("years") or [])
    order = [r["region_id"] for r in json.loads((REPO_ROOT / "data/normalized/regions/region_registry.json").read_text(encoding="utf-8"))["kabkota"]]
    rows = [r for r in observations.read("bnpb_flood_events") if r.get("value") is not None]
    years = sorted({r["reference_period"] for r in rows})
    lines = ["# Flood frequency: production vs multi-year candidate", "", f"Generated {utc_now()}.", "",
             f"- Production years (pinned): {sorted(prod_years)}",
             f"- Years with observations available: {years}", ""]
    if len(years) < 2:
        lines += ["**Multi-year candidate not available**: only one year of BNPB kab/kota flood events is ingested. "
                  "2002–2023 require manual download (G-15; see research/sources/bnpb_yearly_index.md). "
                  "Production model unchanged."]
        OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("multi-year candidate not available (years:", years, ")")
        return 0
    prod = gamma_poisson_rate({}, [r for r in rows if r["reference_period"] in prod_years], order)
    cand = gamma_poisson_rate({}, rows, order)
    obs_years: dict[str, set] = {}
    for r in rows:
        obs_years.setdefault(r["region_id"], set()).add(r["reference_period"])
    completeness = [len(obs_years.get(rid, ())) / len(years) for rid in order]
    def stats(g):
        v = g["values"]
        return {"mean": statistics.mean(v), "median": statistics.median(v), "p90": sorted(v)[int(0.9 * len(v))],
                "max": max(v), "real": g["status"].count("REAL"), "alpha": g["params"]["alpha"], "beta": g["params"]["beta_years"]}
    sp, sc = stats(prod), stats(cand)
    lines += ["| Statistic | Production | Multi-year candidate |", "|---|---:|---:|"]
    for k in ("mean", "median", "p90", "max", "real", "alpha", "beta"):
        lines.append(f"| {k} | {sp[k]:.3f} | {sc[k]:.3f} |")
    lines += ["", f"Mean completeness (observed years / {len(years)}): {statistics.mean(completeness):.2%}", "",
              "## Largest changes (candidate − production, events/year)", "", "| Region | Production | Candidate | Years observed |", "|---|---:|---:|---|"]
    diffs = sorted(range(len(order)), key=lambda i: -abs(cand["values"][i] - prod["values"][i]))[:20]
    for i in diffs:
        lines.append(f"| {order[i]} | {prod['values'][i]:.2f} | {cand['values'][i]:.2f} | {','.join(sorted(obs_years.get(order[i], [])))} |")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"comparison written: {OUT.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
