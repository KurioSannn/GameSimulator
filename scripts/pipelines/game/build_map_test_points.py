"""Build independent hit-test fixtures for the Godot map tests (game/tests/fixtures/map_points.json).

Expected answers come from the lon/lat render geometry (data/processed/geography/.../render/<lod>/) with
the geography v2 point-in-polygon code (scripts/pipelines/geo/v2/geo.py), NOT from the game meshes, so
the Godot test checks projection + triangulated packaging + MapLod hit testing end to end against an
independent source. Every point is verified to lie inside exactly the expected region (or none).

Categories per LOD:
  extreme     interior point of the westernmost / easternmost / northernmost / southernmost part
  multipart   interior point of every part of selected island regions (all must give the same id)
  enclave     a point inside each enclave kota and one in the surrounding kabupaten body
  true_hole   a point inside each hole that no region fills (expected: no region)
  border      points ~30 m either side of a shared border between neighbouring regions
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts/pipelines/geo/v2"))
from geo import interior_point, point_in_polygon, polygons_of  # noqa: E402

SNAP = "SNAP-2026-10-21"
RENDER = ROOT / "data/processed/geography" / SNAP / "render"
OUT = ROOT / "game/tests/fixtures/map_points.json"
MULTIPART = ["31.01", "74.07", "96.03", "81.07", "53.14"]  # Kep. Seribu, Wakatobi, Raja Ampat, Kep. Aru, Rote Ndao
BORDER_PAIRS = 40
OFFSET_DEG = 30.0 / 111_320.0


def project(lon: float, lat: float) -> list[float]:
    return [(lon - 118.0) * math.cos(math.radians(-2.5)) * 100.0, -lat * 100.0]


def regions_containing(pt, feats) -> list[str]:
    return [rid for rid, g in feats.items() if any(point_in_polygon(pt, p) for p in polygons_of(g))]


def bbox_index(feats):
    out = {}
    for rid, g in feats.items():
        xs = [c[0] for p in polygons_of(g) for c in p[0]]
        ys = [c[1] for p in polygons_of(g) for c in p[0]]
        out[rid] = (min(xs), min(ys), max(xs), max(ys))
    return out


def build_lod(lod: str) -> list[dict]:
    feats = {f["properties"]["region_id"]: f["geometry"] for f in json.loads((RENDER / lod / "kabkota.json").read_text())["features"]}
    frags = {f["properties"]["fragment_id"]: f["geometry"] for f in json.loads((RENDER / lod / "fragments.json").read_text())["features"]}
    bbs = bbox_index(feats)
    fbbs = bbox_index(frags)

    def owner(pt) -> list[str]:
        cand = [r for r, b in bbs.items() if b[0] <= pt[0] <= b[2] and b[1] <= pt[1] <= b[3]]
        hit = [r for r in cand if any(point_in_polygon(pt, p) for p in polygons_of(feats[r]))]
        fcand = [r for r, b in fbbs.items() if b[0] <= pt[0] <= b[2] and b[1] <= pt[1] <= b[3]]
        hit += [r for r in fcand if any(point_in_polygon(pt, p) for p in polygons_of(frags[r]))]
        return hit

    points: list[dict] = []

    def add(cat: str, pt, expected: str, note: str = "") -> None:
        got = owner(pt)
        want = [expected] if expected else []
        if got != want:
            return  # not an unambiguous fixture point; skip rather than guess
        points.append({"lod": lod, "category": cat, "lon": pt[0], "lat": pt[1], "expected": expected,
                       "xy": project(pt[0], pt[1]), "note": note})

    # extremes over all parts
    parts = [(rid, p) for rid, g in feats.items() for p in polygons_of(g)]
    for name, key in [("west", lambda rp: min(c[0] for c in rp[1][0])), ("east", lambda rp: -max(c[0] for c in rp[1][0])),
                      ("north", lambda rp: -max(c[1] for c in rp[1][0])), ("south", lambda rp: min(c[1] for c in rp[1][0]))]:
        rid, p = min(parts, key=key)
        add("extreme", interior_point(p), rid, name)
    # multipart regions: every part
    for rid in MULTIPART:
        for i, p in enumerate(polygons_of(feats[rid])):
            add("multipart", interior_point(p), rid, f"part {i}")
    # enclaves and true holes
    for rid, g in feats.items():
        for p in polygons_of(g):
            for h in p[1:]:
                pt = interior_point([h])
                inner = owner(pt)
                if inner:
                    add("enclave", pt, inner[0], f"inside hole of {rid}")
                    add("enclave", interior_point(p), rid, f"body of {rid} around {inner[0]}")
                else:
                    add("true_hole", pt, "", f"hole of {rid} filled by no region")
    # borders: shared consecutive vertices between neighbouring regions
    vert_owner: dict = {}
    for rid, g in feats.items():
        for p in polygons_of(g):
            for ring in p:
                for a, b in zip(ring, ring[1:]):
                    vert_owner.setdefault((round(a[0], 6), round(a[1], 6), round(b[0], 6), round(b[1], 6)), set()).add(rid)
    pairs_done = set()
    for (x0, y0, x1, y1), owners in sorted(vert_owner.items()):
        rev = vert_owner.get((x1, y1, x0, y0), set())
        for a in owners:
            for b in rev:
                key = tuple(sorted((a, b)))
                if a == b or key in pairs_done or len(pairs_done) >= BORDER_PAIRS:
                    continue
                L = math.hypot(x1 - x0, y1 - y0)
                if L < 4 * OFFSET_DEG:
                    continue
                mx, my = (x0 + x1) / 2, (y0 + y1) / 2
                nx, ny = -(y1 - y0) / L * OFFSET_DEG, (x1 - x0) / L * OFFSET_DEG
                before = len(points)
                for pt in ((mx + nx, my + ny), (mx - nx, my - ny)):
                    o = owner(pt)
                    if len(o) == 1 and o[0] in (a, b):
                        add("border", pt, o[0], f"border {key[0]}|{key[1]}")
                if len(points) - before == 2 and points[-1]["expected"] != points[-2]["expected"]:
                    pairs_done.add(key)
                else:
                    del points[before:]
    return points


def main() -> int:
    out = {"generated_by": "scripts/pipelines/game/build_map_test_points.py", "snapshot": SNAP,
           "projection": "x = (lon - 118) * cos(2.5 deg) * 100; y = -lat * 100", "points": []}
    for lod in ("lod1", "lod2", "lod3"):
        pts = build_lod(lod)
        out["points"] += pts
        cats = {}
        for p in pts:
            cats[p["category"]] = cats.get(p["category"], 0) + 1
        print(lod, cats)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=0) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
