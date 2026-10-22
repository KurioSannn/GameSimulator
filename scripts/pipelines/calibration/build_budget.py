"""Build game/data/budget.json (DERIVED) from data/calibration/budget_map.json + APBN observations.

REAL fiscal data (observations `apbn_spending_total`, `apbn_spending_by_function`) stays in the
observation layer. This file only derives: the national discretionary pool (rupiah, for display)
and each sector's baseline share. The simulation uses shares RELATIVE to these baselines
(intensity = share / base_share x spending level), so inserting real rupiah later changes no
equations, only labels and base shares.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

MAP = REPO_ROOT / "data/calibration/budget_map.json"
OUT = REPO_ROOT / "game/data/budget.json"


def main() -> int:
    m = json.loads(MAP.read_text(encoding="utf-8"))
    total = [r for r in observations.read("apbn_spending_total") if r.get("value") is not None and r["region_id"] == "ID"]
    latest = max(total, key=lambda r: r["reference_period"]) if total else None
    by_fn = observations.read("apbn_spending_by_function")
    sectors = {}
    for sid, s in m["sectors"].items():
        # Real shares are used only once every candidate mapping is verified and observations exist.
        sectors[sid] = {"label": s["label"], "base_share": float(s["neutral_share"]), "share_status": "UNCALIBRATED",
                        "apbn_candidates": s["apbn_candidates"], "mapping_status": s["mapping_status"]}
    if by_fn and all(s["mapping_status"] == "VERIFIED" for s in m["sectors"].values()):
        raise SystemExit("real share derivation not implemented yet: implement when APBN function table is ingested")
    out = {
        "schema": "nusantara.game_budget/1", "generated_at": utc_now(),
        "pool_rp": latest["value"] if latest else None,
        "pool_status": "REAL_OFFICIAL" if latest else "UNCALIBRATED",
        "pool_reference_period": latest["reference_period"] if latest else None,
        "pool_source_id": latest["source_id"] if latest else None,
        "level_min": 0.8, "level_max": 1.2,
        "sectors": sectors,
    }
    total_share = sum(s["base_share"] for s in sectors.values())
    if abs(total_share - 100.0) > 1e-6:
        raise SystemExit(f"base shares must sum to 100 (got {total_share})")
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"budget.json: pool {out['pool_status']}, sectors {list(sectors)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
