"""SUPERSEDED (2026-10-22, D-058): the game map now uses geography v2 meshes built by
scripts/pipelines/game/build_map_lods.py from the validated BIG edisi Juni 2026 LODs. Its outputs
(game/data/map/kabkota_lod0.json, kabkota_lod1.json) were removed. Kept for provenance only.

Derive game render geometry from raw BIG kab/kota boundaries (raw is never modified).

Steps:
  1. merge raw per-feature GeoJSON (data/raw/big/kabkota_2023-09/features/*.geojson)
     -> data/processed/geo/kabkota_merged.geojson (gitignored; reproducible)
  2. mapshaper: dissolve by kdpkab (multi-row kab/kota), topology-preserving Visvalingam
     simplification with keep-shapes, drop tiny islands per LOD
  3. project lon/lat to a flat game plane and write game/data/map/kabkota_<lod>.json

Projection: equirectangular centred on lon 118E, x scaled by cos(-2.5 deg) (Indonesia's mid-latitude),
PX_PER_DEG pixels per degree, y down. This is a visual projection only; areas used by the simulation come
from BIG `luaswh`, never from these polygons.
"""
from __future__ import annotations

import json
import math
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, sha256_file, utc_now  # noqa: E402

RAW = REPO_ROOT / "data/raw/big/kabkota_2023-09"
PROC = REPO_ROOT / "data/processed/geo"
OUT = REPO_ROOT / "game/data/map"
MAPSHAPER = REPO_ROOT / "tools/node/node_modules/.bin/mapshaper"
LON0 = 118.0
LAT0 = -2.5
PX_PER_DEG = 100.0
COS0 = math.cos(math.radians(LAT0))
CODE_RE = re.compile(r"^\d\d\.\d\d$")

# LOD settings: share of removable vertices retained, and min island area (km2) to keep (keep-shapes
# guarantees every region keeps at least its largest part).
LODS = {
    "lod0": {"simplify": "0.6%", "min_island_km2": 2.0},   # main interactive map
    "lod1": {"simplify": "0.15%", "min_island_km2": 25.0},  # far zoom / minimap
}


def merge_raw() -> Path:
    PROC.mkdir(parents=True, exist_ok=True)
    merged = PROC / "kabkota_merged.geojson"
    manifest = json.loads((RAW / "MANIFEST.json").read_text(encoding="utf-8"))
    if manifest.get("failed_objectids"):
        raise SystemExit(f"raw download incomplete: {manifest['failed_objectids']}")
    feats = []
    for p in sorted((RAW / "features").glob("*.geojson"), key=lambda p: int(p.stem)):
        fc = json.loads(p.read_text(encoding="utf-8"))
        for f in fc["features"]:
            a = f["properties"]
            code = (a.get("kdpkab") or "").strip()
            f["properties"] = {
                "code": code if CODE_RE.match(code) else "",
                "objectid": a.get("objectid"),
                "disputed": 0 if CODE_RE.match(code) else 1,
            }
            feats.append(f)
    merged.write_text(json.dumps({"type": "FeatureCollection", "features": feats}), encoding="utf-8")
    print(f"merged {len(feats)} features -> {merged} ({merged.stat().st_size / 1e6:.0f} MB)")
    return merged


def run_mapshaper(src: Path, lod: str, cfg: dict) -> Path:
    dst = PROC / f"kabkota_{lod}.geojson"
    cmd = [
        str(MAPSHAPER), "-i", str(src), "snap",
        "-dissolve", "code", "copy-fields=disputed",
        "-simplify", "visvalingam", "weighted", cfg["simplify"], "keep-shapes",
        "-clean",
        "-o", str(dst), "format=geojson", "precision=0.00001", "force",
    ]
    print(" ".join(cmd[1:]))
    subprocess.run(cmd, check=True)
    return dst


def project(lon: float, lat: float) -> tuple[float, float]:
    return (round((lon - LON0) * COS0 * PX_PER_DEG, 2), round(-lat * PX_PER_DEG, 2))


def ring_area(r: list) -> float:
    return 0.5 * sum(r[i][0] * r[i - 1][1] - r[i - 1][0] * r[i][1] for i in range(len(r)))


def approx_km2(flat: list) -> float:
    """Planar area of a projected ring converted back to km2 (equirectangular; adequate for filtering)."""
    a = 0.0
    n = len(flat) // 2
    for i in range(n):
        x1, y1, x0, y0 = flat[2 * i], flat[2 * i + 1], flat[2 * i - 2], flat[2 * i - 1]
        a += x1 * y0 - x0 * y1
    km_per_px = 111.32 / PX_PER_DEG
    return abs(a) / 2.0 * km_per_px * km_per_px


def filter_islands(polys: list, min_km2: float) -> list:
    """Drop parts smaller than min_km2 but ALWAYS keep each region's largest part (no region may vanish)."""
    if not polys:
        return polys
    largest = max(polys, key=lambda p: approx_km2(p["outer"]))
    return [p for p in polys if p is largest or approx_km2(p["outer"]) >= min_km2]


def export(src: Path, lod: str, cfg: dict) -> dict:
    fc = json.loads(src.read_text(encoding="utf-8"))
    regions: dict[str, list] = {}
    disputed: list = []
    n_vertices = 0
    for f in fc["features"]:
        g = f.get("geometry")
        if not g:
            continue
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        out_polys = []
        for poly in polys:
            rings = []
            for ring in poly:
                pts = [project(x, y) for x, y in ring[:-1]]  # drop closing duplicate
                if len(pts) >= 3:
                    rings.append([c for p in pts for c in p])  # flat [x0,y0,x1,y1,...]
                    n_vertices += len(pts)
            if rings:
                out_polys.append({"outer": rings[0], "holes": rings[1:]})
        code = f["properties"].get("code") or ""
        if code:
            regions.setdefault(code, []).extend(out_polys)
        else:
            disputed.extend(out_polys)
    regions = {k: filter_islands(v, cfg["min_island_km2"]) for k, v in regions.items()}
    disputed = [p for p in disputed if approx_km2(p["outer"]) >= cfg["min_island_km2"]]
    n_vertices = sum(len(r) // 2 for polys in regions.values() for p in polys for r in [p["outer"], *p["holes"]])
    xs = [v for polys in regions.values() for p in polys for v in p["outer"][0::2]]
    ys = [v for polys in regions.values() for p in polys for v in p["outer"][1::2]]
    out = {
        "schema": "nusantara.map_geometry/1",
        "fact_class": "DERIVED",
        "generated_at": utc_now(),
        "lod": lod,
        "source": "SRC-BIG-ADM-KABKOTA (edisi 2023-09), raw manifest sha256 "
                  + sha256_file(RAW / "MANIFEST.json")[:16],
        "derivation": {"tool": "mapshaper", "simplify": f"visvalingam weighted {cfg['simplify']} keep-shapes",
                       "min_island_km2": cfg["min_island_km2"], "dissolve": "code (kdpkab)",
                       "projection": f"equirectangular lon0={LON0} lat0={LAT0} px_per_deg={PX_PER_DEG}, y down"},
        "note": "Visual geometry only. Do not compute areas or distances for simulation from these polygons.",
        "bounds": [min(xs), min(ys), max(xs), max(ys)],
        "vertex_count": n_vertices,
        "regions": regions,
        "disputed": disputed,
    }
    OUT.mkdir(parents=True, exist_ok=True)
    dst = OUT / f"kabkota_{lod}.json"
    dst.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print(f"{lod}: {len(regions)} regions, {len(disputed)} disputed polys, {n_vertices} vertices, "
          f"{dst.stat().st_size / 1e6:.1f} MB")
    return out


def main() -> int:
    merged = PROC / "kabkota_merged.geojson"
    if not merged.exists() or "--remerge" in sys.argv:
        merged = merge_raw()
    ok = True
    for lod, cfg in LODS.items():
        out = export(run_mapshaper(merged, lod, cfg), lod, cfg)
        if len(out["regions"]) != 514:
            print(f"ERROR {lod}: expected 514 regions, got {len(out['regions'])}")
            ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
