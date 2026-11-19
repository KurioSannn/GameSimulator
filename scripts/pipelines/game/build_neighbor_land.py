"""Build non-canonical neighboring landmass backdrop outside Indonesia from pinned Natural Earth 1:50m data.

Source: Natural Earth ne_50m_admin_0_countries (Public Domain), commit ca96624a56bd078437bca8184e78163e5039ad19.
Strictly decorative horizon framing only; zero changes to the 514 canonical Indonesian regions or simulation.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data/raw/natural_earth_ne_50m_countries.geojson"
OUT = ROOT / "game/data/map/art/neighbor_land.json"

LON0 = 118.0
LAT0 = -2.5
UNITS_PER_DEG = 100.0
CLIP_MIN_LON = 90.0
CLIP_MAX_LON = 152.0
CLIP_MIN_LAT = -18.5
CLIP_MAX_LAT = 13.5


def project(lon: float, lat: float) -> tuple[float, float]:
    cos_lat = math.cos(math.radians(LAT0))
    return (
        round((lon - LON0) * cos_lat * UNITS_PER_DEG, 2),
        round(-lat * UNITS_PER_DEG, 2),
    )


def _clip_edge(poly: list[tuple[float, float]], inside_fn, intersect_fn) -> list[tuple[float, float]]:
    if not poly:
        return []
    out: list[tuple[float, float]] = []
    prev = poly[-1]
    prev_in = inside_fn(prev)
    for curr in poly:
        curr_in = inside_fn(curr)
        if curr_in:
            if not prev_in:
                out.append(intersect_fn(prev, curr))
            out.append(curr)
        elif prev_in:
            out.append(intersect_fn(prev, curr))
        prev, prev_in = curr, curr_in
    return out


def clip_rect(ring: list[list[float]]) -> list[tuple[float, float]]:
    poly = [(float(p[0]), float(p[1])) for p in ring[:-1]] if len(ring) > 3 and ring[0] == ring[-1] else [(float(p[0]), float(p[1])) for p in ring]
    if len(poly) < 3:
        return []

    def clip_x_min(p): return p[0] >= CLIP_MIN_LON
    def int_x_min(a, b):
        t = (CLIP_MIN_LON - a[0]) / (b[0] - a[0]) if b[0] != a[0] else 0.0
        return (CLIP_MIN_LON, a[1] + t * (b[1] - a[1]))

    def clip_x_max(p): return p[0] <= CLIP_MAX_LON
    def int_x_max(a, b):
        t = (CLIP_MAX_LON - a[0]) / (b[0] - a[0]) if b[0] != a[0] else 0.0
        return (CLIP_MAX_LON, a[1] + t * (b[1] - a[1]))

    def clip_y_min(p): return p[1] >= CLIP_MIN_LAT
    def int_y_min(a, b):
        t = (CLIP_MIN_LAT - a[1]) / (b[1] - a[1]) if b[1] != a[1] else 0.0
        return (a[0] + t * (b[0] - a[0]), CLIP_MIN_LAT)

    def clip_y_max(p): return p[1] <= CLIP_MAX_LAT
    def int_y_max(a, b):
        t = (CLIP_MAX_LAT - a[1]) / (b[1] - a[1]) if b[1] != a[1] else 0.0
        return (a[0] + t * (b[0] - a[0]), CLIP_MAX_LAT)

    for inside_fn, inter_fn in [
        (clip_x_min, int_x_min),
        (clip_x_max, int_x_max),
        (clip_y_min, int_y_min),
        (clip_y_max, int_y_max),
    ]:
        poly = _clip_edge(poly, inside_fn, inter_fn)
        if len(poly) < 3:
            return []
    return poly


def poly_area(pts: list[tuple[float, float]]) -> float:
    acc = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        acc += x1 * y2 - x2 * y1
    return abs(acc) * 0.5


def build() -> None:
    raw_bytes = RAW.read_bytes()
    sha = hashlib.sha256(raw_bytes).hexdigest()
    fc = json.loads(raw_bytes.decode("utf-8"))

    rings_out = []
    countries_used = set()
    for feat in fc["features"]:
        props = feat["properties"]
        iso = str(props.get("ISO_A3", ""))
        admin = str(props.get("ADMIN", ""))
        if iso == "IDN" or admin.lower() == "indonesia":
            continue
        geom = feat.get("geometry")
        if not geom:
            continue
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else geom["coordinates"]
        for poly in polys:
            if not poly:
                continue
            clipped = clip_rect(poly[0])
            if len(clipped) < 3:
                continue
            projected = []
            for lon, lat in clipped:
                pt = project(lon, lat)
                if not projected or math.hypot(pt[0] - projected[-1][0], pt[1] - projected[-1][1]) >= 0.35:
                    projected.append(pt)
            if len(projected) > 2 and math.hypot(projected[0][0] - projected[-1][0], projected[0][1] - projected[-1][1]) < 0.35:
                projected.pop()
            if len(projected) < 3 or poly_area(projected) < 2.0:
                continue
            flat: list[float] = []
            for x, z in projected:
                flat.append(x)
                flat.append(z)
            rings_out.append({
                "iso": iso,
                "name": admin,
                "points": flat,
            })
            countries_used.add(admin)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "nusantara.neighbor_land/1",
        "meaning": "ARTISTIC_BACKDROP; non-canonical neighboring landmass outlines outside Indonesia",
        "source": "Natural Earth ne_50m_admin_0_countries (Public Domain)",
        "commit": "ca96624a56bd078437bca8184e78163e5039ad19",
        "raw_sha256": sha,
        "countries": sorted(countries_used),
        "rings": rings_out,
    }
    OUT.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(f"Built neighbor_land backdrop: {len(rings_out)} landmass polygons across {len(countries_used)} non-Indonesian territories")


if __name__ == "__main__":
    build()
