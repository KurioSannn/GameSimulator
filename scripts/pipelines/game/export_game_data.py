"""Export normalized data into compact game-ready JSON consumed by Godot (game/data/).

Godot never parses raw or research files at runtime; it loads only these exports (docs/10 §8).

Outputs:
  game/data/regions.json  region registry + REAL reference facts per region (from observations)
The simulation baseline (DERIVED) is built separately by scripts/pipelines/calibration/build_baseline.py.

Reference facts are shown in the UI under "Data acuan" with source and period. They are REAL
layer values, kept separate from simulation variables (D-020).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

REG = REPO_ROOT / "data/normalized/regions/region_registry.json"
OUT_DIR = REPO_ROOT / "game/data"
SOURCES = REPO_ROOT / "research/sources/source_registry.json"

# Observation variables surfaced as reference facts, with UI label (Bahasa). Latest period per region.
FACTS = {
    "area_km2": "Luas wilayah",
    "pop_total": "Jumlah penduduk",
    "ipm": "Indeks Pembangunan Manusia",
    "poverty_p0": "Persentase penduduk miskin",
    "unemployment_tpt": "Tingkat pengangguran terbuka",
    "pdrb_adhb": "PDRB atas dasar harga berlaku",
    "official_irbi_total_score": "Skor IRBI resmi (multi-ancaman)",
    "official_irbi_flood_score": "Skor IRBI resmi banjir",
    "bnpb_flood_events": "Kejadian banjir tercatat BNPB",
    "bnpb_flood_affected": "Warga terdampak banjir (BNPB)",
}


def latest_facts(region_ids: set[str]) -> tuple[dict[str, list], dict]:
    inst = {s["source_id"]: s["institution"] for s in json.loads(SOURCES.read_text(encoding="utf-8"))["sources"]}
    per_region: dict[str, list] = {r: [] for r in region_ids}
    used = {}
    for var, label in FACTS.items():
        best: dict[str, dict] = {}
        for row in observations.read(var):
            rid = row["region_id"]
            if rid in per_region and row.get("value") is not None:
                if rid not in best or row["reference_period"] > best[rid]["reference_period"]:
                    best[rid] = row
        for rid, row in best.items():
            per_region[rid].append({"id": var, "label": label, "value": row["value"], "unit": row["unit"],
                                    "period": row["reference_period"], "source_id": row["source_id"],
                                    "fact_class": row["fact_class"]})
            used[row["source_id"]] = inst.get(row["source_id"], row["source_id"])
    return per_region, used


def main() -> int:
    reg = json.loads(REG.read_text(encoding="utf-8"))
    kk = reg["kabkota"]
    facts, used_sources = latest_facts({r["region_id"] for r in kk} | {p["region_id"] for p in reg["provinces"]})
    regions = {
        "schema": "nusantara.game_regions/2",
        "generated_at": utc_now(),
        "admin_baseline": reg["admin_baseline"],
        "geometry_baseline": reg["geometry_baseline"],
        "source_institutions": used_sources,
        "provinces": [{**{k: p[k] for k in ("region_id", "kode_bps", "name", "ibukota", "island_group")},
                       "facts": facts.get(p["region_id"], [])} for p in reg["provinces"]],
        "regions": [{**{k: r[k] for k in ("region_id", "kode_bps", "parent_region_id", "name", "kind", "ibukota", "island_group")},
                     "facts": facts.get(r["region_id"], [])} for r in kk],
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "regions.json").write_text(json.dumps(regions, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    n_facts = sum(len(r["facts"]) for r in regions["regions"])
    print(f"exported {len(kk)} regions, {len(regions['provinces'])} provinces, {n_facts} reference facts")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
