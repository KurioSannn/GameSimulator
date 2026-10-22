"""Build the game map meshes (LOD1/LOD2/LOD3) from the validated geography v2 render LODs.

Input (immutable, lon/lat, DERIVED by scripts/pipelines/geo/v2, D-053):
  data/processed/geography/SNAP-2026-10-21/render/lod{1,2,3}/{kabkota,fragments,provinsi}.json
Output (game asset, loaded offline by MapView):
  game/data/map/v2/kabkota_lod{1,2,3}.json   metadata: provenance, projection, region table, ring ranges
  game/data/map/v2/kabkota_lod{1,2,3}.bin    little-endian sections: float32 positions, float32 region-index
                                             UVs, int32 triangle indices, int32 border line indices,
                                             float32 province outline positions + int32 line indices

Projection (unchanged from the existing game map, so camera/overlay code stays valid):
  equirectangular, lon0 = 118 E, standard parallel 2.5 S (x scaled by cos 2.5 deg), 100 units per
  degree, y down, origin (118 E, 0). One unit = 1/100 degree latitude = 1.1119 km (sphere R 6371 km).
  The source lon/lat files are never modified; projection happens only here, identically for every LOD.

Triangulation: earcut 3.2.3 (tools/geo, via triangulate_rings.mjs) per polygon part with its holes.
Every part's triangulation is checked: earcut `deviation` (relative area mismatch between polygon and
triangles) must stay below MAX_DEVIATION, otherwise the build fails. Region identity is kept per vertex
(UV.x = region index in the game registry's simulation order), so the renderer never needs array
positions or labels to know which region a triangle belongs to.

Usage: .venv/bin/python scripts/pipelines/game/build_map_lods.py
"""
from __future__ import annotations

import json
import math
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, sha256_file, utc_now  # noqa: E402

SNAP = "SNAP-2026-10-21"
RENDER = REPO_ROOT / "data/processed/geography" / SNAP / "render"
GAME_REGIONS = REPO_ROOT / "game/data/regions.json"
OUT = REPO_ROOT / "game/data/map/v2"
TRIANGULATE = REPO_ROOT / "scripts/pipelines/game/triangulate_rings.mjs"

LON0 = 118.0
LAT0 = -2.5
UNITS_PER_DEG = 100.0
COS0 = math.cos(math.radians(LAT0))
KM_PER_UNIT = 2 * math.pi * 6371.0 / 360.0 / UNITS_PER_DEG  # 1/100 degree of latitude on the sphere
MAX_DEVIATION = 1e-6

# View-width bands from research/reports/lod_tolerance_selection.json (D-053), in km.
LODS = {
    "lod1": {"interval_m": 1000, "view_width_km": [2000, None]},
    "lod2": {"interval_m": 100, "view_width_km": [300, 2000]},
    "lod3": {"interval_m": 40, "view_width_km": [None, 300]},
}


def project(lon: float, lat: float) -> tuple[float, float]:
    return ((lon - LON0) * COS0 * UNITS_PER_DEG, -lat * UNITS_PER_DEG)


def polygons_of(geom: dict) -> list:
    return geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]


def ring_xy(ring: list) -> list[tuple[float, float]]:
    pts = [project(c[0], c[1]) for c in ring]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]  # GeoJSON closes rings; the mesh uses implicit closure
    return pts


def triangulate(parts: list[list[list[tuple[float, float]]]]) -> list[dict]:
    with tempfile.TemporaryDirectory() as tmp:
        src, dst = Path(tmp) / "in.json", Path(tmp) / "out.json"
        src.write_text(json.dumps({"parts": [{"rings": [[v for p in r for v in p] for r in rings]} for rings in parts]}))
        subprocess.run(["node", str(TRIANGULATE), str(src), str(dst)], check=True)
        return json.loads(dst.read_text())["parts"]


def build(lod: str, cfg: dict, order: list[str], parents: dict[str, str]) -> dict:
    d = RENDER / lod
    kab = {f["properties"]["region_id"]: f for f in json.loads((d / "kabkota.json").read_text())["features"]}
    frag = sorted(json.loads((d / "fragments.json").read_text())["features"], key=lambda f: f["properties"]["fragment_id"])
    prov = sorted(json.loads((d / "provinsi.json").read_text())["features"], key=lambda f: f["properties"]["region_id"])
    if set(kab) != set(order):
        raise SystemExit(f"{lod}: render ids differ from game registry: {sorted(set(kab) ^ set(order))[:10]}")

    # Region table: the 514 kab/kota in simulation order, then the 21 unallocated fragments (D-052).
    entries = [(rid, "kabkota", kab[rid]["geometry"], parents[rid]) for rid in order]
    entries += [(f["properties"]["fragment_id"], "fragment", f["geometry"], f["properties"]["parent_region_id"]) for f in frag]

    parts, owner = [], []
    for idx, (_rid, _kind, geom, _p) in enumerate(entries):
        for poly in polygons_of(geom):
            parts.append([ring_xy(r) for r in poly])
            owner.append(idx)
    tri = triangulate(parts)
    worst = max(t["deviation"] for t in tri)
    bad = [(entries[owner[i]][0], t["deviation"]) for i, t in enumerate(tri) if t["deviation"] > MAX_DEVIATION]
    if bad:
        raise SystemExit(f"{lod}: triangulation deviation above {MAX_DEVIATION} for {len(bad)} parts: {bad[:5]}")

    positions, uvs, tris, lines = [], [], [], []
    regions = []
    part_i = 0
    for idx, (rid, kind, geom, parent) in enumerate(entries):
        v0, t0, rings_meta = len(positions), len(tris), []
        bx0 = by0 = math.inf
        bx1 = by1 = -math.inf
        for pi, poly in enumerate(polygons_of(geom)):
            rings = parts[part_i]
            base = len(positions)
            for ri, r in enumerate(rings):
                start = len(positions)
                positions.extend(r)
                uvs.extend([(float(idx), 0.0)] * len(r))
                for k in range(len(r)):
                    lines += [start + k, start + (k + 1) % len(r)]
                rings_meta.append([start, len(r), pi, 1 if ri > 0 else 0])
                for x, y in r:
                    bx0, by0, bx1, by1 = min(bx0, x), min(by0, y), max(bx1, x), max(by1, y)
            tris.extend(base + k for k in tri[part_i]["tris"])
            part_i += 1
        regions.append({"id": rid, "kind": kind, "parent": parent,
                        "v": [v0, len(positions) - v0], "t": [t0, len(tris) - t0],
                        "rings": rings_meta, "bbox": [round(bx0, 4), round(by0, 4), round(bx1, 4), round(by1, 4)]})

    prov_pos, prov_lines, prov_meta = [], [], []
    for f in prov:
        p0 = len(prov_pos)
        for poly in polygons_of(f["geometry"]):
            for r in poly:
                pts = ring_xy(r)
                start = len(prov_pos)
                prov_pos.extend(pts)
                for k in range(len(pts)):
                    prov_lines += [start + k, start + (k + 1) % len(pts)]
        prov_meta.append({"id": f["properties"]["region_id"], "v": [p0, len(prov_pos) - p0]})

    blob = bytearray()
    sections = {}

    def put(name: str, fmt: str, values: list, comps: int) -> None:
        sections[name] = {"offset": len(blob), "count": len(values) // comps if comps > 1 else len(values),
                          "type": "float32" if fmt == "f" else "int32", "components": comps}
        blob.extend(struct.pack(f"<{len(values)}{fmt}", *values))
        sections[name]["bytes"] = len(blob) - sections[name]["offset"]

    put("positions", "f", [c for p in positions for c in p], 2)
    put("region_uv", "f", [c for p in uvs for c in p], 2)
    put("triangles", "i", tris, 1)
    put("lines", "i", lines, 1)
    put("province_positions", "f", [c for p in prov_pos for c in p], 2)
    put("province_lines", "i", prov_lines, 1)

    OUT.mkdir(parents=True, exist_ok=True)
    bin_path = OUT / f"kabkota_{lod}.bin"
    bin_path.write_bytes(bytes(blob))
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]
    src_files = {n: sha256_file(d / n) for n in ("kabkota.json", "fragments.json", "provinsi.json", "build_log.json")}
    build_log = json.loads((d / "build_log.json").read_text())
    meta = {
        "schema": "nusantara.map_mesh/1",
        "fact_class": "DERIVED",
        "generated_at": utc_now(),
        "lod": lod,
        "interval_m": cfg["interval_m"],
        "view_width_km": cfg["view_width_km"],
        "source": {
            "snapshot": SNAP,
            "render_dir": str(d.relative_to(REPO_ROOT)),
            "sha256": src_files,
            "simplify_method": build_log.get("simplify_method"),
            "mapshaper_version": build_log.get("mapshaper_version"),
            "decision": "D-053",
            "note": "BIG edisi Juni 2026 (SRC-0001); Kab. Sumbawa from the 1e-7 deg recovery copy (D-056).",
        },
        "projection": {"name": "equirectangular", "lon0": LON0, "lat0_standard_parallel": LAT0,
                       "units_per_degree": UNITS_PER_DEG, "y_down": True, "origin_lonlat": [LON0, 0.0],
                       "km_per_unit": KM_PER_UNIT,
                       "formula": "x = (lon - 118) * cos(2.5 deg) * 100; y = -lat * 100"},
        "triangulation": {"tool": "earcut 3.2.3", "max_deviation": worst, "limit": MAX_DEVIATION},
        "note": "Visual geometry only. Never derive official areas or distances from these polygons (D-055).",
        "bounds": [min(xs), min(ys), max(xs), max(ys)],
        "counts": {"regions": len(order), "fragments": len(frag), "parts": len(parts),
                   "vertices": len(positions), "triangles": len(tris) // 3, "province_vertices": len(prov_pos)},
        "bin": {"file": bin_path.name, "bytes": len(blob), "sha256": sha256_file(bin_path), "sections": sections},
        "regions": regions,
        "provinces": prov_meta,
    }
    (OUT / f"kabkota_{lod}.json").write_text(json.dumps(meta, separators=(",", ":")), encoding="utf-8")
    print(f"{lod}: {len(order)} regions + {len(frag)} fragments, {len(parts)} parts, {len(positions)} vertices, "
          f"{len(tris) // 3} triangles, max deviation {worst:.2e}, bin {len(blob) / 1e6:.2f} MB")
    return meta


def main() -> int:
    game = json.loads(GAME_REGIONS.read_text(encoding="utf-8"))
    order = [r["region_id"] for r in game["regions"]]
    parents = {r["region_id"]: r["parent_region_id"] for r in game["regions"]}
    if len(order) != 514 or len(set(order)) != 514:
        raise SystemExit("game registry must hold 514 unique kab/kota")
    for lod, cfg in LODS.items():
        build(lod, cfg, order, parents)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
