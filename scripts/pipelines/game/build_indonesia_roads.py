"""Build compact offline Indonesian road network geometry for the game map from immutable
official Kementerian Pekerjaan Umum (Bina Marga & BPJT) GeoJSON captures.

Inputs (immutable raw captures):
  data/raw/pupr_roads/jalan_nasional_bina_marga.geojson
  data/raw/pupr_roads/jalan_tol_bpjt_operasi.geojson
  data/raw/pupr_roads/MANIFEST.json

Outputs (offline game assets):
  game/data/map/art/indonesia_roads.json   provenance, stats, binary section layout
  game/data/map/art/indonesia_roads.bin    little-endian float32 positions + int32 polyline ranges

Projection matches build_map_lods.py identically:
  equirectangular, lon0 = 118.0 E, standard parallel -2.5 S, 100 units/deg, z = -lat * 100.

Usage: python scripts/pipelines/game/build_indonesia_roads.py
"""
from __future__ import annotations

import json
import math
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, sha256_file, utc_now  # noqa: E402

RAW_DIR = REPO_ROOT / "data/raw/pupr_roads"
OUT_DIR = REPO_ROOT / "game/data/map/art"

LON0 = 118.0
LAT0 = -2.5
UNITS_PER_DEG = 100.0
COS0 = math.cos(math.radians(LAT0))
KM_PER_UNIT = 2.0 * math.pi * 6371.0 / 360.0 / UNITS_PER_DEG

# Simplification tolerances in map world units (1 wu ~= 1.1119 km):
# 0.20 wu (~220m) keeps every curve of Jalan Nasional crisp while reducing 3.19M pts -> ~55k pts.
# 0.10 wu (~110m) keeps urban/interchange Toll Road geometry ultra-sharp.
NATIONAL_TOL_WU = 0.11
TOLL_TOL_WU = 0.05


def _rdp_indices(pts: np.ndarray, tol: float) -> np.ndarray:
    """Iterative Ramer-Douglas-Peucker returning sorted kept indices of Nx2 float64 array."""
    n = len(pts)
    if n <= 2:
        return np.arange(n, dtype=np.int32)
    keep = np.zeros(n, dtype=bool)
    keep[0] = True
    keep[-1] = True
    tol2 = tol * tol
    stack: list[tuple[int, int]] = [(0, n - 1)]
    while stack:
        i0, i1 = stack.pop()
        if i1 - i0 <= 1:
            continue
        p0 = pts[i0]
        p1 = pts[i1]
        seg = p1 - p0
        seg_len2 = float(seg[0] * seg[0] + seg[1] * seg[1])
        mid = pts[i0 + 1 : i1]
        diff = mid - p0
        if seg_len2 < 1e-12:
            d2 = diff[:, 0] ** 2 + diff[:, 1] ** 2
        else:
            t = np.clip((diff[:, 0] * seg[0] + diff[:, 1] * seg[1]) / seg_len2, 0.0, 1.0)
            proj_x = seg[0] * t
            proj_y = seg[1] * t
            d2 = (diff[:, 0] - proj_x) ** 2 + (diff[:, 1] - proj_y) ** 2
        rel = int(np.argmax(d2))
        if float(d2[rel]) > tol2:
            split = i0 + 1 + rel
            keep[split] = True
            stack.append((i0, split))
            stack.append((split, i1))
    return np.flatnonzero(keep)


def _extract_polylines(geojson_path: Path, tol_wu: float, min_len_wu: float = 0.08) -> tuple[np.ndarray, np.ndarray, float, int]:
    fc = json.loads(geojson_path.read_text(encoding="utf-8"))
    all_pts: list[np.ndarray] = []
    ranges: list[tuple[int, int]] = []
    cursor = 0
    total_wu = 0.0
    raw_pts_total = 0

    for feat in fc.get("features", []):
        geom = feat.get("geometry")
        if not geom:
            continue
        gtype = geom.get("type")
        if gtype == "LineString":
            lines = [geom["coordinates"]]
        elif gtype == "MultiLineString":
            lines = geom["coordinates"]
        else:
            continue

        for coords in lines:
            if not coords or len(coords) < 2:
                continue
            raw_pts_total += len(coords)
            arr = np.asarray([[float(c[0]), float(c[1])] for c in coords], dtype=np.float64)
            # Clip sanity to Indonesian archipelago geographic bounds
            valid = (arr[:, 0] >= 94.0) & (arr[:, 0] <= 142.0) & (arr[:, 1] >= -12.0) & (arr[:, 1] <= 7.0)
            if not np.all(valid):
                arr = arr[valid]
                if len(arr) < 2:
                    continue
            proj = np.empty_like(arr)
            proj[:, 0] = (arr[:, 0] - LON0) * COS0 * UNITS_PER_DEG
            proj[:, 1] = -arr[:, 1] * UNITS_PER_DEG

            # Drop near-identical consecutive points
            diffs = np.diff(proj, axis=0)
            seg_d = np.hypot(diffs[:, 0], diffs[:, 1])
            keep_nz = np.concatenate(([True], seg_d > 1e-4))
            proj = proj[keep_nz]
            if len(proj) < 2:
                continue

            # Split accidental jumps > 35 wu (~39 km) from broken multi-island links
            diffs = np.diff(proj, axis=0)
            seg_d = np.hypot(diffs[:, 0], diffs[:, 1])
            breaks = np.flatnonzero(seg_d > 35.0)
            starts = np.concatenate(([0], breaks + 1))
            ends = np.concatenate((breaks + 1, [len(proj)]))

            for s_idx, e_idx in zip(starts, ends):
                sub = proj[s_idx:e_idx]
                if len(sub) < 2:
                    continue
                sub_len = float(np.hypot(np.diff(sub[:, 0]), np.diff(sub[:, 1])).sum())
                if sub_len < min_len_wu:
                    continue
                kept_idx = _rdp_indices(sub, tol_wu)
                simp = sub[kept_idx].astype(np.float32)
                if len(simp) < 2:
                    continue
                total_wu += float(np.hypot(np.diff(simp[:, 0]), np.diff(simp[:, 1])).sum())
                all_pts.append(simp)
                ranges.append((cursor, len(simp)))
                cursor += len(simp)

    pts_out = np.vstack(all_pts).astype("<f4") if all_pts else np.zeros((0, 2), dtype="<f4")
    rng_out = np.asarray(ranges, dtype="<i4").reshape(-1, 2) if ranges else np.zeros((0, 2), dtype="<i4")
    return pts_out, rng_out, total_wu * KM_PER_UNIT, raw_pts_total


def build() -> None:
    manifest_path = RAW_DIR / "MANIFEST.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"Missing {manifest_path}; run fetch_indonesia_roads.py first.")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    nat_path = RAW_DIR / "jalan_nasional_bina_marga.geojson"
    tol_path = RAW_DIR / "jalan_tol_bpjt_operasi.geojson"

    nat_pts, nat_rng, nat_km, nat_raw_pts = _extract_polylines(nat_path, NATIONAL_TOL_WU, min_len_wu=0.10)
    tol_pts, tol_rng, tol_km, tol_raw_pts = _extract_polylines(tol_path, TOLL_TOL_WU, min_len_wu=0.06)

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bin_path = OUT_DIR / "indonesia_roads.bin"
    sections: dict[str, dict] = {}
    buf = bytearray()

    def write_section(name: str, arr: np.ndarray, dtype_name: str, components: int) -> None:
        while len(buf) % 4 != 0:
            buf.append(0)
        offset = len(buf)
        raw_bytes = arr.tobytes()
        buf.extend(raw_bytes)
        sections[name] = {
            "offset": offset,
            "count": int(arr.shape[0]),
            "components": components,
            "dtype": dtype_name,
            "bytes": len(raw_bytes),
        }

    write_section("national_positions", nat_pts, "float32", 2)
    write_section("national_ranges", nat_rng, "int32", 2)
    write_section("toll_positions", tol_pts, "float32", 2)
    write_section("toll_ranges", tol_rng, "int32", 2)

    bin_path.write_bytes(bytes(buf))
    bin_sha = sha256_file(bin_path)

    payload = {
        "schema": "nusantara.roads/1",
        "meaning": "REAL_OFFICIAL_INFRASTRUCTURE_GEOMETRY; derived from Kementerian PU Bina Marga Jalan Nasional and BPJT Jalan Tol Operasi",
        "built_at": utc_now(),
        "projection": {
            "type": "equirectangular",
            "lon0": LON0,
            "lat0": LAT0,
            "units_per_deg": UNITS_PER_DEG,
            "km_per_unit": round(KM_PER_UNIT, 6),
        },
        "simplification": {
            "method": "Ramer-Douglas-Peucker (map world units)",
            "national_tol_wu": NATIONAL_TOL_WU,
            "toll_tol_wu": TOLL_TOL_WU,
        },
        "sources": manifest.get("datasets", []),
        "stats": {
            "national_polylines": int(nat_rng.shape[0]),
            "national_points": int(nat_pts.shape[0]),
            "national_raw_points": int(nat_raw_pts),
            "national_km_approx": round(nat_km, 1),
            "toll_polylines": int(tol_rng.shape[0]),
            "toll_points": int(tol_pts.shape[0]),
            "toll_raw_points": int(tol_raw_pts),
            "toll_km_approx": round(tol_km, 1),
        },
        "bin": {
            "file": bin_path.name,
            "bytes": len(buf),
            "sha256": bin_sha,
            "sections": sections,
        },
    }
    json_path = OUT_DIR / "indonesia_roads.json"
    json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(
        f"Built {bin_path.name} ({len(buf) / 1024:.1f} KB): "
        f"Jalan Nasional {nat_rng.shape[0]} lines / {nat_pts.shape[0]} pts (~{nat_km:,.0f} km from {nat_raw_pts:,} raw pts); "
        f"Jalan Tol {tol_rng.shape[0]} lines / {tol_pts.shape[0]} pts (~{tol_km:,.0f} km from {tol_raw_pts:,} raw pts)"
    )


if __name__ == "__main__":
    build()
