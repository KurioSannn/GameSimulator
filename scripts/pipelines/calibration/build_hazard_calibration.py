"""Derive the flood severity scale (flood_severity_mean) and record how it was obtained.

Why this exists: BNPB impact data give affected persons per event, but converting that into our
damage index (share of regional capacity impaired) requires regional population, which is blocked
on the BPS key (G-01). Until then, the per-event severity mean mu is chosen so that the EXPECTED
national flood damage per year equals the level validated in the IRBI milestone (commit 9636fdd:
untouched term -> about -5 national sentiment), now distributed by REAL frequencies:

  D_ref = sum_i  lambda_ref_i * 4.0,   lambda_ref_i = 0.35 * 5.0 * (official IRBI flood score_i / 36)   [previous model]
  D_new = sum_i  lambda_i * scale_i * mu,   scale_i = 0.5 + flood_risk_profile_i / 100
  mu    = D_ref / sum_i(lambda_i * scale_i)

Activation rule once population exists (documented, not yet used):
  points_per_event_i = 100 * (bnpb_flood_affected_i / bnpb_flood_events_i) / population_i
Writes the value into game/data/sim_params.json (coefficient flood_severity_mean) and a report.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

PARAMS = REPO_ROOT / "game/data/sim_params.json"
BASE = REPO_ROOT / "game/data/baseline.json"


def main() -> int:
    b = json.loads(BASE.read_text(encoding="utf-8"))
    order = b["region_order"]
    lam = b["variables"]["flood_frequency"]["values"]
    prof = b["variables"]["flood_risk_profile"]["values"] or [50.0] * len(order)
    if lam is None:
        print("flood_frequency not calibrated; keeping existing severity mean")
        return 0
    irbi = {r["region_id"]: r["value"] for r in observations.read("official_irbi_flood_score") if r.get("value") is not None}
    d_ref = sum(0.35 * 5.0 * irbi.get(rid, 0.0) / 36.0 * 4.0 for rid in order)
    denom = sum(l * (0.5 + p / 100.0) for l, p in zip(lam, prof))
    mu = d_ref / denom
    params = json.loads(PARAMS.read_text(encoding="utf-8"))
    params["coefficients"]["flood_severity_mean"] = {
        "value": round(mu, 6),
        "intent": "Mean damage points per flood event before modifiers (Exp distribution). DERIVED by "
                  "scripts/pipelines/calibration/build_hazard_calibration.py to preserve the validated national "
                  "expected flood damage while using REAL BNPB frequencies. Population-based empirical anchor pending (G-01).",
        "derivation": {"D_ref_points_per_year": round(d_ref, 3), "sum_lambda_scale": round(denom, 3),
                       "national_expected_events_per_year": round(sum(lam), 1), "built_at": utc_now()},
    }
    PARAMS.write_text(json.dumps(params, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"flood_severity_mean = {mu:.4f} (D_ref {d_ref:.1f} pts/yr over {sum(lam):.0f} expected events/yr)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
