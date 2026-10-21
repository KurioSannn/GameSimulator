"""Cross-check dissolved province outlines against BIG's official province boundary lines.

There is no edisi-Juni-2026 province polygon layer (GAP-0006), so province
outlines are dissolved from the kab/kota polygons (SRC-0001). This script
compares them with BIG's separate province boundary *line* layer (SRC-0007,
segments dated 2021-05 .. 2024-09). Edition differences mean perfect agreement
is not expected; the report breaks results down by line edition.

For each sampled line vertex:
  distance_m      distance to the nearest province-outline segment (local metric)
  side_match      the nearest outline belongs to one of the two provinces the
                  official line separates (WAPRO1 / WAPRO2)

Usage:
  python3 scripts/research/compare_province_lines.py data/processed/geography/<snap>/render/lod3
Writes research/reports/province_outline_crosscheck.json
"""

from __future__ import annotations

import argparse
import json
import math
import re
import statistics
from collections import Counter, defaultdict
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, utc_now_iso
from geo import polygons_of

CELL = 0.02  # degrees
SAMPLE_EVERY = 5


def norm(s: str) -> str:
    return re.sub(r"[^A-Z]", "", (s or "").upper())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("lod_dir")
    args = ap.parse_args()

    reg = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))
    name_to_pid = {norm(p["name"]): p["region_id"] for p in reg["provinces"]}
    name_to_pid[norm("Daerah Istimewa Yogyakarta")] = "34"  # BIG spelling of DI YOGYAKARTA
    prov = json.loads((Path(args.lod_dir) / "provinsi.json").read_text())["features"]

    def build_grid(features):
        grid = defaultdict(list)
        for f in features:
            pid = f["properties"]["region_id"]
            for poly in polygons_of(f["geometry"]):
                for ring in poly:
                    for a, b in zip(ring, ring[1:]):
                        x0, x1 = sorted((a[0], b[0]))
                        y0, y1 = sorted((a[1], b[1]))
                        seg = (pid, a[0], a[1], b[0], b[1])
                        for gx in range(math.floor(x0 / CELL), math.floor(x1 / CELL) + 1):
                            for gy in range(math.floor(y0 / CELL), math.floor(y1 / CELL) + 1):
                                grid[(gx, gy)].append(seg)
        return grid

    prov_grid = build_grid(prov)
    kab_grid = build_grid(json.loads((Path(args.lod_dir) / "kabkota.json").read_text())["features"])

    def nearest(grid, lon, lat, max_rings=25):
        kx = 111_320 * math.cos(math.radians(lat))
        ky = 110_574
        cx, cy = math.floor(lon / CELL), math.floor(lat / CELL)
        best = (float("inf"), None)
        for r in range(max_rings + 1):
            cells = [(cx + i, cy + j) for i in range(-r, r + 1) for j in range(-r, r + 1)
                     if max(abs(i), abs(j)) == r]
            for c in cells:
                for pid, ax, ay, bx, by in grid.get(c, ()):
                    px, py = (lon - ax) * kx, (lat - ay) * ky
                    vx, vy = (bx - ax) * kx, (by - ay) * ky
                    L = vx * vx + vy * vy
                    t = 0.0 if L == 0 else max(0.0, min(1.0, (px * vx + py * vy) / L))
                    d = math.hypot(px - t * vx, py - t * vy)
                    if d < best[0]:
                        best = (d, pid)
            # every unsearched segment is at least r cells away; stop once the best hit is nearer
            if best[1] is not None and best[0] < r * CELL * min(kx, ky):
                break
        return best

    raw = DATA_RAW / "SRC-0007" / args.snapshot
    results = []
    unknown_names = Counter()
    for page in sorted(raw.glob("provinsi_lines_geom_*.geojson")):
        for f in json.loads(page.read_text())["features"]:
            p = f["properties"]
            pair = {name_to_pid.get(norm(p.get("WAPRO1") or p.get("wapro1"))),
                    name_to_pid.get(norm(p.get("WAPRO2") or p.get("wapro2")))}
            for side in ("WAPRO1", "WAPRO2"):
                nm = p.get(side) or p.get(side.lower())
                if nm and not name_to_pid.get(norm(nm)):
                    unknown_names[nm] += 1
            m = re.search(r"(\d{8})KABKOTA", p.get("METADATA") or p.get("metadata") or "")
            edition = m.group(1) if m else "unknown"
            g = f["geometry"]
            lines = g["coordinates"] if g["type"] == "MultiLineString" else [g["coordinates"]]
            inter = None not in pair and len(pair) == 2  # boundary between two provinces
            for line in lines:
                for c in line[::SAMPLE_EVERY]:
                    dk, _ = nearest(kab_grid, c[0], c[1])
                    rec = {"edition": edition, "inter_province": inter, "d_kab": dk}
                    if inter:
                        d, pid = nearest(prov_grid, c[0], c[1])
                        rec.update({"d": d, "side_match": pid in pair})
                    results.append(rec)

    def summarize(rs, key="d"):
        ds = sorted(r[key] for r in rs if key in r and math.isfinite(r[key]))
        sm = [r["side_match"] for r in rs if "side_match" in r]
        if not ds:
            return {"n": 0}
        return {"n": len(ds), "median_m": statistics.median(ds), "p90_m": ds[int(0.9 * (len(ds) - 1))],
                "p95_m": ds[int(0.95 * (len(ds) - 1))],
                **{f"within_{t}m_pct": 100 * sum(d <= t for d in ds) / len(ds) for t in (10, 50, 100, 500, 1000)},
                "side_match_pct": 100 * sum(sm) / len(sm) if sm else None,
                "beyond_search_radius": sum(1 for r in rs if key in r and not math.isfinite(r[key]))}

    inter = [r for r in results if r["inter_province"]]
    by_ed = defaultdict(list)
    for r in inter:
        by_ed[r["edition"]].append(r)
    report = {"snapshot_id": args.snapshot, "built_at": utc_now_iso(), "lod_dir": str(Path(args.lod_dir)),
              "sample_every_nth_vertex": SAMPLE_EVERY,
              "note": "SRC-0007 layer 8 holds kab/kota-level boundary lines with WAPRO1/WAPRO2; only lines "
                      "with two different provinces are province boundaries (primary comparison). "
                      "All lines are also compared with the kab/kota borders (secondary).",
              "inter_province_vs_province_outlines": summarize(inter),
              "inter_province_by_line_edition": {k: summarize(v) for k, v in sorted(by_ed.items())},
              "all_lines_vs_kabkota_borders": summarize(results, "d_kab"),
              "line_samples_total": len(results), "line_samples_inter_province": len(inter),
              "unmatched_province_names_in_lines": dict(unknown_names)}
    out = REPO_ROOT / "research" / "reports" / "province_outline_crosscheck.json"
    out.write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
