"""Build non-canonical neighboring landmass backdrop outside Indonesia from pinned Natural Earth 1:50m data.

Source: Natural Earth ne_50m_admin_0_countries (Public Domain), commit ca96624a56bd078437bca8184e78163e5039ad19.
Strictly decorative horizon framing only; zero changes to the 514 canonical Indonesian regions or simulation.
"""
from __future__ import annotations
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import distance_transform_edt, zoom

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data/raw/natural_earth_ne_50m_countries.geojson"
OUT = ROOT / "game/data/map/art/neighbor_land.json"
FIELD_OUT = ROOT / "game/data/map/art/neighbor_field.png"
CATALOG_PATH = ROOT / "game/data/map/art_catalog.json"
SEED = 20261120

LON0 = 118.0
LAT0 = -2.5
UNITS_PER_DEG = 100.0
CLIP_MIN_LON = 82.0
CLIP_MAX_LON = 162.0
CLIP_MIN_LAT = -26.0
CLIP_MAX_LAT = 22.0


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


def _fractal_grid(rng: np.random.Generator, shape: tuple[int, int], octaves: list[tuple[int, int, float]]) -> np.ndarray:
    h, w = shape
    acc = np.zeros((h, w), dtype=np.float32)
    weight_sum = 0.0
    for gh, gw, w_oct in octaves:
        coarse = rng.random((gh, gw), dtype=np.float32)
        up = zoom(coarse, (h / gh, w / gw), order=1, mode="nearest")[:h, :w]
        acc += up * w_oct
        weight_sum += w_oct
    return np.clip(acc / max(weight_sum, 1e-6), 0.0, 1.0)


def _points_in_ring(pxs: np.ndarray, pzs: np.ndarray, ring_pts: list[tuple[float, float]]) -> np.ndarray:
    poly = np.asarray(ring_pts, dtype=np.float64)
    n = len(poly)
    inside = np.zeros(len(pxs), dtype=bool)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        denom = (zj - zi)
        cond = (zi > pzs) != (zj > pzs)
        if abs(denom) > 1e-12:
            x_int = (xj - xi) * (pzs - zi) / denom + xi
            cross = cond & (pxs < x_int)
            inside ^= cross
        j = i
    return inside


def build() -> None:
    raw_bytes = RAW.read_bytes()
    sha = hashlib.sha256(raw_bytes).hexdigest()
    fc = json.loads(raw_bytes.decode("utf-8"))
    catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))["groups"]

    rings_out = []
    ring_polys: list[tuple[list[tuple[float, float]], float]] = []
    countries_used = set()
    all_x: list[float] = []
    all_z: list[float] = []

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
            area = poly_area(projected)
            if len(projected) < 3 or area < 2.0:
                continue
            flat: list[float] = []
            for x, z in projected:
                flat.append(x)
                flat.append(z)
                all_x.append(x)
                all_z.append(z)
            rings_out.append({
                "iso": iso,
                "name": admin,
                "points": flat,
            })
            ring_polys.append((projected, area))
            countries_used.add(admin)

    # Bake neighbor terrain field: R=land mask, G=inland distance / 90, B=artistic mountain ridge relief
    fx0 = min(all_x) - 120.0
    fx1 = max(all_x) + 120.0
    fz0 = min(all_z) - 120.0
    fz1 = max(all_z) + 120.0
    width, height = 1536, 768
    dx = (fx1 - fx0) / (width - 1)
    dy = (fz1 - fz0) / (height - 1)

    mask_img = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask_img)
    for poly_pts, _ in ring_polys:
        draw.polygon([((x - fx0) / dx, (z - fz0) / dy) for x, z in poly_pts], fill=255)
    mask = np.asarray(mask_img) > 0
    inside = distance_transform_edt(mask, sampling=(dy, dx))

    rng = np.random.default_rng(SEED)
    n_ridge_a = _fractal_grid(rng, (height, width), [(20, 40, 0.55), (48, 96, 0.30), (112, 224, 0.15)])
    n_ridge_b = _fractal_grid(rng, (height, width), [(30, 64, 0.62), (84, 176, 0.38)])
    ridge_raw = 0.60 * (1.0 - np.abs(2.0 * n_ridge_a - 1.0)) + 0.40 * (1.0 - np.abs(2.0 * n_ridge_b - 1.0))
    ridge_raw = np.power(np.clip(ridge_raw, 0.0, 1.0), 1.35)
    spine_mask = np.clip((inside - 2.2) / 34.0, 0.0, 1.0)
    ridge_relief = np.clip(ridge_raw * spine_mask, 0.0, 1.0)

    field_img = np.stack([
        mask.astype(np.uint8) * 255,
        np.clip(inside / 90.0, 0.0, 1.0) * 255.0,
        ridge_relief * 255.0,
    ], axis=2).astype(np.uint8)
    FIELD_OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(field_img).save(FIELD_OUT)

    # Scatter trees, palms, highland conifers, shrubs & rocks across neighboring territories
    occupied: dict[tuple[int, int], list[tuple[float, float, float]]] = {}
    cell_size = 7.5

    def can_place(x: float, z: float, rad: float) -> bool:
        cx, cz = int(math.floor(x / cell_size)), int(math.floor(z / cell_size))
        for ix in range(cx - 2, cx + 3):
            for iz in range(cz - 2, cz + 3):
                for ox, oz, orad in occupied.get((ix, iz), ()):
                    lim = rad + orad
                    if (x - ox) * (x - ox) + (z - oz) * (z - oz) < lim * lim:
                        return False
        return True

    def occupy(x: float, z: float, rad: float) -> None:
        cx, cz = int(math.floor(x / cell_size)), int(math.floor(z / cell_size))
        occupied.setdefault((cx, cz), []).append((x, z, rad))

    total_area = sum(a for _, a in ring_polys)
    target_props = 1900
    neighbor_props: list[dict] = []
    variants = {"tree": 0, "highland_tree": 0, "palm": 0, "shrub": 0, "rock": 0}

    # Stratified target per polygon so both large mainlands and tiny Philippines/Timor islands look populated
    for poly_pts, area in ring_polys:
        if area < 16.0:
            continue
        arr = np.asarray(poly_pts, dtype=np.float64)
        bx0, bz0 = arr.min(axis=0)
        bx1, bz1 = arr.max(axis=0)
        quota = min(240, max(2, int(round(target_props * (0.45 * (area / max(total_area, 1.0)) + 0.55 * math.sqrt(area) / 1450.0)))))
        n_cand = max(64, quota * 16)
        cxs = rng.uniform(bx0, bx1, n_cand)
        czs = rng.uniform(bz0, bz1, n_cand)
        inside_poly = _points_in_ring(cxs, czs, poly_pts)
        placed = 0
        for x, z, ok in zip(cxs, czs, inside_poly):
            if not ok or z < -1150.0 or z > 1550.0 or x < -2750.0 or x > 2850.0:
                continue
            px = int(np.clip((x - fx0) / dx, 0, width - 1))
            py = int(np.clip((z - fz0) / dy, 0, height - 1))
            clr = float(inside[py, px])
            if clr < 2.2:
                continue
            ridge = float(ridge_relief[py, px])
            # Southern islands around arid Australia have sparser scrubland & rock outcrops
            is_arid_south = z > 1050.0
            if ridge > 0.48 and clr > 14.0 and rng.random() < 0.14:
                kind = "rock"
                sz = float(rng.uniform(0.11, 0.21))
                rad = float(catalog[kind]["footprint"]) * sz * 0.36
            elif is_arid_south and rng.random() < 0.58:
                kind = "shrub" if rng.random() < 0.65 else "rock"
                sz = float(rng.uniform(0.18, 0.34) if kind == "shrub" else rng.uniform(0.10, 0.17))
                rad = float(catalog[kind]["footprint"]) * sz * 0.34
            elif ridge > 0.34 and clr > 13.0 and rng.random() < 0.54:
                kind = "highland_tree"
                sz = float(rng.uniform(0.19, 0.32))
                rad = float(catalog[kind]["footprint"]) * sz * 0.42
            elif clr < 13.0 and rng.random() < 0.52:
                kind = "palm"
                sz = float(rng.uniform(0.16, 0.27))
                rad = float(catalog[kind]["footprint"]) * sz * 0.38
            elif rng.random() < 0.16:
                kind = "shrub"
                sz = float(rng.uniform(0.20, 0.36))
                rad = float(catalog[kind]["footprint"]) * sz * 0.34
            else:
                kind = "tree"
                sz = float(rng.uniform(0.18, 0.33))
                rad = float(catalog[kind]["footprint"]) * sz * 0.42

            rx = round(float(x), 3)
            rz = round(float(z), 3)
            if not can_place(rx, rz, rad):
                continue
            v = variants[kind] % len(catalog[kind]["models"])
            variants[kind] += 1
            neighbor_props.append({
                "x": rx,
                "z": rz,
                "region": -1,
                "kind": kind,
                "variant": v,
                "rotation": round(float(rng.random() * math.pi * 2.0), 4),
                "size": round(sz, 3),
                "role": "decoration",
            })
            occupy(rx, rz, rad)
            placed += 1
            if placed >= quota:
                break

    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "schema": "nusantara.neighbor_land/1",
        "meaning": "ARTISTIC_BACKDROP; non-canonical neighboring landmass outlines outside Indonesia",
        "source": "Natural Earth ne_50m_admin_0_countries (Public Domain)",
        "commit": "ca96624a56bd078437bca8184e78163e5039ad19",
        "raw_sha256": sha,
        "field_bounds": [round(fx0, 2), round(fz0, 2), round(fx1 - fx0, 2), round(fz1 - fz0, 2)],
        "field_size": [width, height],
        "field_channels": "R=land,G=inland_distance/90,B=artistic_relief",
        "countries": sorted(countries_used),
        "rings": rings_out,
        "props": neighbor_props,
    }
    OUT.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(f"Built neighbor_land backdrop: {len(rings_out)} landmass polygons across {len(countries_used)} non-Indonesian territories, {len(neighbor_props)} neighbor props")


if __name__ == "__main__":
    build()
