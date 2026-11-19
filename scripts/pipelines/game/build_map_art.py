"""Reproducible display-only coastline field, landscape detail relief, and decorative placements.

Input is the existing, immutable LOD1 triangulation and region metadata. No geography or
simulation state is changed. SciPy's exact distance transform creates coastal falloff.
Props, vessels, clouds, and detail maps use a fixed NumPy RNG and are validated inside
canonical region triangles. This is purely artistic dressing, NOT measured elevation,
land cover, bathymetry, shipping traffic, or settlement extent datasets.
"""
from __future__ import annotations
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import scipy
from scipy.ndimage import distance_transform_edt, gaussian_filter, zoom

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "game/data/map/v2/kabkota_lod1.json"
OUT = ROOT / "game/data/map/art"
SEED = 20261119


def _fact_value(record: dict, fact_id: str, default: float = 0.0) -> float:
    for fact in record.get("facts", []):
        if fact.get("id") == fact_id and fact.get("value") is not None:
            return float(fact["value"])
    return default


def _fractal_grid(rng: np.random.Generator, shape: tuple[int, int], octaves: list[tuple[int, int, float]]) -> np.ndarray:
    h, w = shape
    acc = np.zeros((h, w), dtype=np.float32)
    weight_sum = 0.0
    for gh, gw, w_oct in octaves:
        coarse = rng.random((gh, gw), dtype=np.float32)
        up = zoom(coarse, (h / gh, w / gw), order=1, mode="nearest")
        up = up[:h, :w]
        acc += up * w_oct
        weight_sum += w_oct
    return np.clip(acc / max(weight_sum, 1e-6), 0.0, 1.0)


def build() -> None:
    meta = json.loads(SOURCE.read_text(encoding="utf-8"))
    raw = SOURCE.with_suffix(".bin").read_bytes()

    def section(name: str, dtype: str, components: int) -> np.ndarray:
        s = meta["bin"]["sections"][name]
        return np.frombuffer(raw, dtype=dtype, count=s["count"] * components, offset=s["offset"]).reshape(-1, components)

    xy = section("positions", "<f4", 2)
    indices = section("triangles", "<i4", 1).reshape(-1, 3)
    uv = section("region_uv", "<f4", 2)
    tri = xy[indices].astype(np.float64)
    ab, ac = tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]
    areas = np.abs(ab[:, 0] * ac[:, 1] - ab[:, 1] * ac[:, 0]) / 2.0

    x0, y0, x1, y1 = meta["bounds"]
    x0 -= 240.0
    y0 -= 240.0
    x1 += 240.0
    y1 += 240.0
    width, height = 4096, 1792
    dx, dy = (x1 - x0) / (width - 1), (y1 - y0) / (height - 1)

    image = Image.new("L", (width, height))
    draw = ImageDraw.Draw(image)
    for points in tri:
        draw.polygon([((x - x0) / dx, (y - y0) / dy) for x, y in points], fill=255)
    # Union higher-detail LOD2/LOD3 silhouettes onto the visual coast_field so zoomed-in capes
    # never evaluate mask == 0 (which made sharp peninsulas turn solid brown sand).
    for lod_name in ("kabkota_lod2", "kabkota_lod3"):
        lod_json = ROOT / f"game/data/map/v2/{lod_name}.json"
        lod_bin = ROOT / f"game/data/map/v2/{lod_name}.bin"
        if lod_json.exists() and lod_bin.exists():
            l_meta = json.loads(lod_json.read_text(encoding="utf-8"))
            l_raw = lod_bin.read_bytes()
            l_pos_s = l_meta["bin"]["sections"]["positions"]
            l_tri_s = l_meta["bin"]["sections"]["triangles"]
            l_xy = np.frombuffer(l_raw, dtype="<f4", count=l_pos_s["count"] * 2, offset=l_pos_s["offset"]).reshape(-1, 2)
            l_idx = np.frombuffer(l_raw, dtype="<i4", count=l_tri_s["count"], offset=l_tri_s["offset"]).reshape(-1, 3)
            for points in l_xy[l_idx]:
                draw.polygon([((float(x) - x0) / dx, (float(y) - y0) / dy) for x, y in points], fill=255)
    mask = np.asarray(image) > 0
    inside = distance_transform_edt(mask, sampling=(dy, dx))
    outside = distance_transform_edt(~mask, sampling=(dy, dx))
    grad_out_y, grad_out_x = np.gradient(outside.astype(np.float32))

    # R encodes land mask, G sea distance / 180 world units, B inland distance / 90 units.
    field = np.stack([
        mask * 255,
        np.clip(outside / 180.0, 0.0, 1.0) * 255,
        np.clip(inside / 90.0, 0.0, 1.0) * 255,
    ], axis=2).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray(field).save(OUT / "coast_field.png")

    rng = np.random.default_rng(SEED)
    catalog_path = ROOT / "game/data/map/art_catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))["groups"]
    region_for_tri = uv[indices[:, 0], 0].astype(int)
    registry = json.loads((ROOT / "game/data/regions.json").read_text(encoding="utf-8"))

    prov_capitals = {(str(p["region_id"]), str(p.get("ibukota", "")).strip().lower()) for p in registry["provinces"]}
    mega_kota_ids = {"12.71", "16.71", "21.71", "31.71", "31.72", "31.73", "31.74", "31.75", "32.73", "32.75", "32.76", "33.74", "35.78", "36.71", "64.71", "73.71"}

    placements: list[dict] = []
    variants = Counter()
    urban_stamps: list[tuple[float, float, float]] = []

    # Fast 2D spatial hash prevents overlapping props/trees while running in O(1) time.
    cell_size = 3.5
    occupied: dict[tuple[int, int], list[tuple[float, float, float, bool]]] = defaultdict(list)

    def can_place(x: float, z: float, radius: float, pad: float = 0.0, ignore_roads: bool = False) -> bool:
        r_req = radius + pad
        cx, cz = int(np.floor(x / cell_size)), int(np.floor(z / cell_size))
        span = int(np.ceil((r_req + 6.0) / cell_size))
        for ix in range(cx - span, cx + span + 1):
            for iz in range(cz - span, cz + span + 1):
                for ox, oz, orad, is_road in occupied.get((ix, iz), ()):
                    if ignore_roads and is_road:
                        continue
                    lim = r_req + orad
                    if (x - ox) * (x - ox) + (z - oz) * (z - oz) < lim * lim:
                        return False
        return True

    def occupy(x: float, z: float, radius: float, is_road: bool = False) -> None:
        cx, cz = int(np.floor(x / cell_size)), int(np.floor(z / cell_size))
        occupied[(cx, cz)].append((x, z, radius, is_road))

    def add(
        kind: str,
        region: int,
        x: float,
        z: float,
        size: float = 1.0,
        rotation: float = 0.0,
        role: str = "decoration",
        variant_override: int | None = None,
    ) -> None:
        models = catalog[kind]["models"]
        if variant_override is not None:
            variant = int(variant_override) % len(models)
        else:
            variant = variants[kind] % len(models)
        variants[kind] += 1
        placements.append({
            "x": round(float(x), 3),
            "z": round(float(z), 3),
            "region": int(region),
            "kind": kind,
            "variant": variant,
            "rotation": round(float(rotation), 4),
            "size": round(float(size), 3),
            "role": role,
        })

    def fits_boxes(points: np.ndarray, triangles: np.ndarray, lo: np.ndarray, hi: np.ndarray) -> bool:
        for point in points:
            nearby = triangles[np.all(point >= lo - 1e-7, axis=1) & np.all(point <= hi + 1e-7, axis=1)]
            if not len(nearby):
                return False
            a, b = nearby[:, 1] - nearby[:, 0], nearby[:, 2] - nearby[:, 0]
            p = point - nearby[:, 0]
            determinant = a[:, 0] * b[:, 1] - a[:, 1] * b[:, 0]
            valid = np.abs(determinant) > 1e-10
            u = (p[:, 0] * b[:, 1] - p[:, 1] * b[:, 0]) / np.where(valid, determinant, 1.0)
            v = (a[:, 0] * p[:, 1] - a[:, 1] * p[:, 0]) / np.where(valid, determinant, 1.0)
            if not np.any(valid & (u >= -1e-7) & (v >= -1e-7) & (u + v <= 1.0 + 1e-7)):
                return False
        return True

    footprint_samples = np.array([[a, b] for a in (-0.5, 0.0, 0.5) for b in (-0.5, 0.0, 0.5)])
    micro_cross = np.array([[0.0, 0.0], [0.004, 0.0], [-0.004, 0.0], [0.0, 0.004], [0.0, -0.004]])
    cores: list[tuple[np.ndarray, float]] = []
    region_urban_tier: dict[int, int] = {}
    region_geom: dict[int, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}

    def world_to_px(x: float, z: float) -> tuple[int, int]:
        px = int(np.clip((x - x0) / dx, 0, width - 1))
        py = int(np.clip((z - y0) / dy, 0, height - 1))
        return px, py

    def try_place_settlement(
        kind: str,
        region: int,
        x: float,
        z: float,
        scale: float,
        rot: float,
        region_tri: np.ndarray,
        lo: np.ndarray,
        hi: np.ndarray,
        variant_override: int | None = None,
        collision_scale: float = 0.44,
        glow_weight: float = 0.6,
        record_urban: bool = True,
    ) -> bool:
        rx = round(float(x), 3)
        rz = round(float(z), 3)
        rs = round(float(scale), 3)
        rr = round(float(rot), 4)
        if rs < 0.005:
            return False
        radius = float(catalog[kind]["footprint"]) * rs * collision_scale
        if not can_place(rx, rz, radius, ignore_roads=(kind == "vehicle")):
            return False
        rot_m = np.array([[np.cos(rr), np.sin(rr)], [-np.sin(rr), np.cos(rr)]])
        offsets = footprint_samples @ rot_m.T
        fp_exact = np.array([rx, rz]) + offsets * (float(catalog[kind]["footprint"]) * rs)
        fp_padded = np.array([rx, rz]) + offsets * (float(catalog[kind]["footprint"]) * rs * 1.02)
        if not fits_boxes(np.vstack([fp_exact, fp_padded, np.array([rx, rz]) + micro_cross]), region_tri, lo, hi):
            return False
        add(kind, region, rx, rz, rs, rr, role="settlement", variant_override=variant_override)
        occupy(rx, rz, radius, is_road=(kind == "road"))
        if record_urban:
            urban_stamps.append((rx, rz, glow_weight))
        return True

    road_step_unit = float(catalog["road"]["footprint"])

    for region, record in enumerate(registry["regions"]):
        allowed = np.flatnonzero(region_for_tri == region)
        if not len(allowed):
            raise ValueError(f"Missing canonical geometry: {record['region_id']}")
        region_tri = tri[allowed]
        reg_areas = areas[allowed]
        lo, hi = region_tri.min(axis=1), region_tri.max(axis=1)
        region_geom[region] = (region_tri, lo, hi)
        total_area = float(reg_areas.sum())
        largest = allowed[int(np.argmax(reg_areas))]
        center = tri[largest].mean(axis=0)

        rid = str(record["region_id"])
        is_kota = record["kind"] == "kota"
        pop = _fact_value(record, "pop_total", 0.0)
        area_km2 = max(_fact_value(record, "area_km2", 1.0), 1.0)
        density = pop / area_km2
        is_cap = (str(record.get("parent_region_id", "")), str(record.get("ibukota", "")).strip().lower()) in prov_capitals

        if is_kota and (rid in mega_kota_ids or pop >= 900_000):
            tier = 3
        elif is_kota and (pop >= 250_000 or is_cap):
            tier = 2
        elif is_kota or density >= 900.0 or pop >= 1_200_000:
            tier = 1
        else:
            tier = 0
        region_urban_tier[region] = tier

        angle = (region * 2.3999632297) % (2.0 * np.pi)
        rot_m = np.array([[np.cos(angle), np.sin(angle)], [-np.sin(angle), np.cos(angle)]])
        rot_fp = footprint_samples @ rot_m.T

        if tier >= 3:
            base_scale = min(0.24, max(0.085, np.sqrt(total_area) / 68.0))
        elif tier == 2:
            base_scale = min(0.22, max(0.08, np.sqrt(total_area) / 80.0))
        elif tier == 1:
            base_scale = min(0.18, max(0.075, np.sqrt(total_area) / 96.0))
        else:
            base_scale = min(0.16, max(0.07, np.sqrt(total_area) / 118.0))

        core_kind = "tower" if is_kota else "house"
        cx_q = round(float(center[0]), 3)
        cz_q = round(float(center[1]), 3)
        ang_q = round(float(angle), 4)
        rot_mq = np.array([[np.cos(ang_q), np.sin(ang_q)], [-np.sin(ang_q), np.cos(ang_q)]])
        rot_fpq = footprint_samples @ rot_mq.T
        core_scale = base_scale
        while True:
            rc = round(core_scale, 3)
            pts_c = np.vstack([
                np.array([cx_q, cz_q]) + rot_fpq * (float(catalog[core_kind]["footprint"]) * rc),
                np.array([cx_q, cz_q]) + rot_fpq * (float(catalog[core_kind]["footprint"]) * rc * 1.02),
            ])
            if fits_boxes(pts_c, region_tri, lo, hi):
                break
            core_scale *= 0.82
        add(core_kind, region, cx_q, cz_q, round(core_scale, 3), ang_q, role="city_core" if is_kota else "village_core")
        occupy(float(center[0]), float(center[1]), float(catalog[core_kind]["footprint"]) * core_scale * 0.48)
        cores.append((center, core_scale))
        urban_stamps.append((float(center[0]), float(center[1]), 1.35 if tier >= 2 else 0.7))

        # Structured downtown/town street plaza around core center
        r_scale = max(0.08, core_scale * 0.92)
        step = road_step_unit * r_scale
        # Place main crossroad axis offsets carefully outside core center or flanking center
        road_arm_range = [-1, 1] if tier <= 1 else [-2, -1, 1, 2]
        road_coords = []
        # Flanking intersection road tiles next to CBD center (offset +Z one lane so towers aren't on asphalt)
        for ix in [-1, 0, 1]:
            rx, rz = center + rot_m @ np.array([ix * step, step])
            var_r = 1 if ix == 0 else (6 if abs(ix) == 1 and tier == 0 else 0)
            if try_place_settlement("road", region, rx, rz, r_scale, angle, region_tri, lo, hi, variant_override=var_r, collision_scale=0.38, glow_weight=0.45):
                road_coords.append((rx, rz, r_scale, angle))
        for iz in road_arm_range:
            if iz == 1:
                continue
            rx, rz = center + rot_m @ np.array([0.0, iz * step])
            var_r = 3 if (iz == -1 and tier >= 2 and region % 2 == 0) else (2 if abs(iz) == 1 else (4 if tier >= 2 and region % 3 == 0 else (5 if region % 3 == 1 else 0)))
            if try_place_settlement("road", region, rx, rz, r_scale, angle + np.pi * 0.5, region_tri, lo, hi, variant_override=var_r, collision_scale=0.38, glow_weight=0.4):
                road_coords.append((rx, rz, r_scale, angle + np.pi * 0.5))

        # Vehicles and streetlights along placed downtown roads
        for rx, rz, rs, rang in road_coords[: (6 if tier >= 2 else 3)]:
            v_rot_m = np.array([[np.cos(rang), np.sin(rang)], [-np.sin(rang), np.cos(rang)]])
            vx, vz = np.array([rx, rz]) + v_rot_m @ np.array([0.0, 2.2 * rs])
            try_place_settlement("vehicle", region, vx, vz, max(0.09, rs * 0.85), rang, region_tri, lo, hi, collision_scale=0.32, record_urban=False)
            if tier >= 1:
                lx, lz = np.array([rx, rz]) + v_rot_m @ np.array([5.5 * rs, -6.2 * rs])
                try_place_settlement("streetlight", region, lx, lz, max(0.11, rs * 0.72), rang, region_tri, lo, hi, collision_scale=0.22, record_urban=False)

        # Curated CBD & inner block ring around core
        cbd_slots: list[tuple[str, float, float, float, float]] = []
        if tier == 3:
            for ix in [-2, -1, 0, 1, 2]:
                for iz in [-2, -1, 0, 2, 3]:
                    if ix == 0 and iz in (0, 1):
                        continue
                    dist = abs(ix) + abs(iz)
                    k = "tower" if dist <= 2 else ("midrise" if dist <= 3 else "urban_block")
                    s_mul = 1.05 if k == "tower" else 0.96
                    cbd_slots.append((k, ix * step * 1.05, iz * step * 1.05, (np.pi * 0.5) * ((ix + iz) % 4), s_mul))
        elif tier == 2:
            for ix in [-2, -1, 0, 1, 2]:
                for iz in [-1, 0, 2]:
                    if ix == 0 and iz in (0, 1):
                        continue
                    dist = abs(ix) + abs(iz)
                    k = "tower" if dist == 1 else ("midrise" if dist <= 2 else "urban_block")
                    cbd_slots.append((k, ix * step * 1.06, iz * step * 1.06, (np.pi * 0.5) * ((ix + iz) % 4), 0.94))
        elif tier == 1:
            for ix, iz, k in [(-1, 0, "midrise"), (1, 0, "midrise"), (-1, -1, "urban_block"), (1, -1, "urban_block"), (-2, 0, "house"), (2, 0, "house"), (0, 2, "house"), (-1, 2, "house"), (1, 2, "house")]:
                cbd_slots.append((k, ix * step * 1.06, iz * step * 1.06, 0.0 if ix >= 0 else np.pi, 0.92))
        else:
            for ix, iz, k in [(-1, 0, "house"), (1, 0, "house"), (-1, 2, "house"), (1, 2, "house"), (0, -1, "house")]:
                cbd_slots.append((k, ix * step * 1.08, iz * step * 1.08, 0.0 if ix >= 0 else np.pi, 0.92))

        for k, ox, oz, local_rot, s_mul in cbd_slots:
            pos = center + rot_m @ np.array([ox, oz])
            b_scale = min(0.23, core_scale * s_mul)
            w_g = 1.15 if k == "tower" else (0.85 if k in ("midrise", "urban_block") else 0.45)
            try_place_settlement(k, region, float(pos[0]), float(pos[1]), b_scale, angle + local_rot, region_tri, lo, hi, glow_weight=w_g)

        # Polygon-wide multi-district urban sprawl, port/industrial zones, and suburban neighborhoods
        n_candidates = 240 if tier == 3 else (130 if tier == 2 else (65 if tier == 1 else 22))
        target_extra = 85 if tier == 3 else (46 if tier == 2 else (20 if tier == 1 else 6))
        cum_reg = np.cumsum(reg_areas)
        tri_picks = np.searchsorted(cum_reg, rng.random(n_candidates) * cum_reg[-1])
        pts = region_tri[tri_picks]
        ra = rng.random((n_candidates, 1))
        rb = rng.random((n_candidates, 1))
        flip = ra + rb > 1.0
        ra[flip] = 1.0 - ra[flip]
        rb[flip] = 1.0 - rb[flip]
        cand_xy = pts[:, 0] + ra * (pts[:, 1] - pts[:, 0]) + rb * (pts[:, 2] - pts[:, 0])

        # Prioritize proximity to urban center on compact/metro cities so sprawl stays cohesive!
        if tier >= 2:
            dists = np.hypot(cand_xy[:, 0] - center[0], cand_xy[:, 1] - center[1])
            order = np.argsort(dists * rng.uniform(0.75, 1.35, size=len(dists)))
            cand_xy = cand_xy[order]

        extra_placed = 0
        for cx, cz in cand_xy:
            if extra_placed >= target_extra:
                break
            px, py = world_to_px(float(cx), float(cz))
            clearance = float(inside[py, px])
            dist_core = float(np.hypot(cx - center[0], cz - center[1]))
            local_rot = float((rng.integers(0, 4) * (np.pi * 0.5)) + angle)

            if tier >= 2 and clearance < 13.5 and rng.random() < 0.52:
                # Maritime Harbor & Industrial Corridor near coast!
                pick_ind = rng.random()
                if pick_ind < 0.48:
                    k, sc = "industrial", float(rng.uniform(0.11, 0.19))
                elif pick_ind < 0.85:
                    k, sc = "port_cargo", float(rng.uniform(0.11, 0.18))
                else:
                    k, sc = "road", float(rng.uniform(0.11, 0.16))
                if try_place_settlement(k, region, float(cx), float(cz), sc, local_rot, region_tri, lo, hi, glow_weight=0.75):
                    extra_placed += 1
                    if k == "road":
                        vx, vz = float(cx) + np.cos(local_rot) * 1.4 * sc, float(cz) + np.sin(local_rot) * 1.4 * sc
                        try_place_settlement("vehicle", region, vx, vz, sc * 0.85, local_rot, region_tri, lo, hi, collision_scale=0.3, record_urban=False)
                continue

            if tier >= 3:
                if dist_core < max(12.0, np.sqrt(total_area) * 0.36):
                    roll = rng.random()
                    k = "tower" if roll < 0.32 else ("midrise" if roll < 0.72 else "urban_block")
                    sc = float(rng.uniform(0.10, 0.21 if k == "tower" else 0.19))
                    wg = 1.1 if k == "tower" else 0.85
                else:
                    roll = rng.random()
                    k = "urban_block" if roll < 0.36 else ("midrise" if roll < 0.55 else ("industrial" if roll < 0.65 else ("road" if roll < 0.72 else "house")))
                    sc = float(rng.uniform(0.10, 0.18))
                    wg = 0.65 if k != "house" else 0.4
            elif tier == 2:
                roll = rng.random()
                k = "midrise" if roll < 0.30 else ("urban_block" if roll < 0.60 else ("industrial" if roll < 0.70 else "house"))
                sc = float(rng.uniform(0.09, 0.17))
                wg = 0.7 if k != "house" else 0.4
            elif tier == 1:
                roll = rng.random()
                k = "urban_block" if roll < 0.22 else ("industrial" if roll < 0.34 else ("midrise" if roll < 0.42 else "house"))
                sc = float(rng.uniform(0.09, 0.16))
                wg = 0.55 if k != "house" else 0.35
            else:
                # Rural kabupaten: small inland/coastal kampung house clusters
                if clearance < 3.5 or (total_area > 800 and rng.random() < 0.45):
                    continue
                k = "house"
                sc = float(rng.uniform(0.08, 0.14))
                wg = 0.25

            if try_place_settlement(k, region, float(cx), float(cz), sc, local_rot, region_tri, lo, hi, glow_weight=wg):
                extra_placed += 1
                if k == "road":
                    vx, vz = float(cx) + np.cos(local_rot) * 1.4 * sc, float(cz) + np.sin(local_rot) * 1.4 * sc
                    try_place_settlement("vehicle", region, vx, vz, sc * 0.85, local_rot, region_tri, lo, hi, collision_scale=0.3, record_urban=False)

    # Bake landscape_detail.png (R=urban_glow, G=biome_richness, B=artistic_relief)
    urban_map = np.zeros((height, width), dtype=np.float32)
    for ux, uz, weight in urban_stamps:
        px, py = world_to_px(ux, uz)
        urban_map[py, px] = min(2.5, urban_map[py, px] + weight)
    urban_glow = (
        0.55 * gaussian_filter(urban_map, sigma=3.2)
        + 0.45 * gaussian_filter(urban_map, sigma=8.5)
    )
    urban_glow = np.clip(urban_glow * 4.5, 0.0, 1.0)
    urban_glow[~mask] = 0.0

    n_macro = _fractal_grid(rng, (height, width), [(14, 32, 0.55), (28, 64, 0.30), (64, 144, 0.15)])
    n_ridge_a = _fractal_grid(rng, (height, width), [(24, 56, 0.50), (52, 120, 0.32), (112, 256, 0.18)])
    n_ridge_b = _fractal_grid(rng, (height, width), [(36, 84, 0.60), (96, 220, 0.40)])
    ridge_raw = 0.62 * (1.0 - np.abs(2.0 * n_ridge_a - 1.0)) + 0.38 * (1.0 - np.abs(2.0 * n_ridge_b - 1.0))
    ridge_raw = np.power(np.clip(ridge_raw, 0.0, 1.0), 1.35)
    spine_mask = np.clip((inside - 2.0) / 36.0, 0.0, 1.0)
    ridge_relief = np.clip(ridge_raw * spine_mask * (1.0 - 0.72 * urban_glow), 0.0, 1.0)

    biome_richness = np.clip(
        0.52 * np.clip(inside / 28.0, 0.0, 1.0)
        + 0.48 * n_macro
        - 0.35 * urban_glow,
        0.0,
        1.0,
    )
    detail_img = np.stack([
        np.clip(urban_glow, 0.0, 1.0) * 255.0,
        np.clip(biome_richness, 0.0, 1.0) * 255.0,
        np.clip(ridge_relief, 0.0, 1.0) * 255.0,
    ], axis=2).astype(np.uint8)
    Image.fromarray(detail_img).save(OUT / "landscape_detail.png")

    # Scatter rich natural tropical forests, highland pine ridges, palms, volcanic rocks, crops & undergrowth!
    cumulative = np.cumsum(areas)
    n_nature_samples = 72000
    chosen = np.searchsorted(cumulative, rng.random(n_nature_samples) * cumulative[-1])
    points = tri[chosen]
    na = rng.random((n_nature_samples, 1))
    nb = rng.random((n_nature_samples, 1))
    flip = na + nb > 1.0
    na[flip] = 1.0 - na[flip]
    nb[flip] = 1.0 - nb[flip]
    samples = points[:, 0] + na * (points[:, 1] - points[:, 0]) + nb * (points[:, 2] - points[:, 0])

    region_nature_counts: Counter[int] = Counter()
    nature_count = 0
    for n, (x, y) in enumerate(samples):
        if nature_count >= 17200:
            break
        region = int(uv[indices[chosen[n], 0], 0])
        if region >= 514:
            continue
        px, py = world_to_px(float(x), float(y))
        clearance = float(inside[py, px])
        if clearance < 1.8:
            continue
        u_dens = float(urban_glow[py, px])
        if u_dens > 0.32:
            continue
        ridge = float(ridge_relief[py, px])
        biome = float(biome_richness[py, px])

        if ridge > 0.48 and clearance > 18.0 and rng.random() < 0.12:
            kind = "rock"
            sz = float(rng.uniform(0.09, 0.18))
            rad = float(catalog[kind]["footprint"]) * sz * 0.34
        elif ridge > 0.36 and clearance > 15.0 and rng.random() < 0.56:
            kind = "highland_tree"
            sz = float(rng.uniform(0.16, 0.30))
            rad = float(catalog[kind]["footprint"]) * sz * 0.35
        elif clearance < 14.0 and rng.random() < 0.55:
            kind = "palm"
            sz = float(rng.uniform(0.14, 0.24))
            rad = float(catalog[kind]["footprint"]) * sz * 0.33
        elif biome < 0.58 and clearance > 7.0 and u_dens < 0.18 and rng.random() < 0.18:
            kind = "crop"
            sz = float(rng.uniform(0.22, 0.38))
            rad = float(catalog[kind]["footprint"]) * sz * 0.33
        elif rng.random() < 0.15:
            kind = "shrub"
            sz = float(rng.uniform(0.18, 0.34))
            rad = float(catalog[kind]["footprint"]) * sz * 0.30
        else:
            kind = "tree"
            sz = float(rng.uniform(0.15, 0.30))
            rad = float(catalog[kind]["footprint"]) * sz * 0.34

        rx = round(float(x), 3)
        rz = round(float(y), 3)
        r_tri, r_lo, r_hi = region_geom[region]
        if not can_place(rx, rz, rad):
            continue
        if not fits_boxes(np.array([rx, rz]) + micro_cross, r_tri, r_lo, r_hi):
            continue
        add(kind, region, rx, rz, sz, float(rng.random() * np.pi * 2.0), role="decoration")
        occupy(rx, rz, rad)
        nature_count += 1
        region_nature_counts[region] += 1

    # Stratified per-region flora guarantee so outer & tiny islands (Anambas, Sangihe, Maluku, NTT) never look barren
    for region in range(len(registry["regions"])):
        r_tri, r_lo, r_hi = region_geom[region]
        allowed = np.flatnonzero(region_for_tri == region)
        if not len(allowed):
            continue
        reg_areas = areas[allowed]
        total_reg_area = float(reg_areas.sum())
        min_flora = min(14, max(4, int(round(np.sqrt(total_reg_area) * 1.15))))
        if region_nature_counts[region] >= min_flora:
            continue
        reg_cum = np.cumsum(reg_areas)
        n_cand = 96
        picks = np.searchsorted(reg_cum, rng.random(n_cand) * reg_cum[-1])
        pts = r_tri[picks]
        sa = rng.random((n_cand, 1))
        sb = rng.random((n_cand, 1))
        fl = sa + sb > 1.0
        sa[fl] = 1.0 - sa[fl]
        sb[fl] = 1.0 - sb[fl]
        reg_samples = pts[:, 0] + sa * (pts[:, 1] - pts[:, 0]) + sb * (pts[:, 2] - pts[:, 0])
        for sx, sz_pos in reg_samples:
            if region_nature_counts[region] >= min_flora:
                break
            px, py = world_to_px(float(sx), float(sz_pos))
            clearance = float(inside[py, px])
            if clearance < 0.45 or float(urban_glow[py, px]) > 0.36:
                continue
            small_mul = 0.65 if clearance < 1.8 else 0.90
            if clearance < 9.0 and rng.random() < 0.62:
                kind = "palm"
                sz = float(rng.uniform(0.10, 0.20) * small_mul)
            elif rng.random() < 0.24:
                kind = "shrub"
                sz = float(rng.uniform(0.14, 0.26) * small_mul)
            else:
                kind = "tree"
                sz = float(rng.uniform(0.11, 0.22) * small_mul)
            rad = float(catalog[kind]["footprint"]) * sz * 0.28
            rx = round(float(sx), 3)
            rz = round(float(sz_pos), 3)
            if not can_place(rx, rz, rad):
                continue
            if not fits_boxes(np.array([rx, rz]) + micro_cross, r_tri, r_lo, r_hi):
                continue
            add(kind, region, rx, rz, sz, float(rng.random() * np.pi * 2.0), role="decoration")
            occupy(rx, rz, rad)
            nature_count += 1
            region_nature_counts[region] += 1

    # Offshore Vessels along Indonesia sea lanes & major port approaches (outside land polygons!)
    vessels: list[dict] = []
    coastal_hub_xy = np.array([
        cores[i][0] for i in range(len(cores)) if region_urban_tier.get(i, 0) >= 2
    ])
    vessel_pts: list[tuple[float, float]] = []
    # Guarantee all 8 watercraft models appear across ports & open archipelagic waters
    cargo_variants = [0, 1, 2, 3, 4, 5]
    small_variants = [6, 7]
    for _ in range(9000):
        if len(vessels) >= 136:
            break
        vx = float(rng.uniform(x0 + 180.0, x1 - 180.0))
        vz = float(rng.uniform(y0 + 140.0, y1 - 140.0))
        px, py = world_to_px(vx, vz)
        sea_dist = float(outside[py, px])
        if sea_dist < 10.5 or sea_dist > 110.0:
            continue
        if any((vx - sx) ** 2 + (vz - sz) ** 2 < 44.0 ** 2 for sx, sz in vessel_pts):
            continue
        near_port = bool(len(coastal_hub_xy) and np.min(np.sum((coastal_hub_xy - [vx, vz]) ** 2, axis=1)) < 120.0 ** 2)
        if near_port and sea_dist < 42.0:
            variant = cargo_variants[len(vessels) % len(cargo_variants)]
            v_size = float(rng.uniform(0.20, 0.34))
        elif rng.random() < 0.38:
            variant = cargo_variants[len(vessels) % len(cargo_variants)]
            v_size = float(rng.uniform(0.22, 0.36))
        else:
            variant = small_variants[len(vessels) % len(small_variants)]
            v_size = float(rng.uniform(0.18, 0.28))

        gx = float(grad_out_x[py, px])
        gz = float(grad_out_y[py, px])
        coast_heading = float(np.arctan2(gx, gz) + (np.pi * 0.5 if len(vessels) % 2 == 0 else -np.pi * 0.5))
        heading = coast_heading + float(rng.uniform(-0.35, 0.35))

        # Fit safe verified sea-lane patrol loop around (vx, vz) so moving ships never clip islands
        fwd_x, fwd_z = float(np.sin(heading)), float(np.cos(heading))
        right_x, right_z = fwd_z, -fwd_x
        cruise_a, cruise_b = 0.0, 0.0
        for scale_try in (1.0, 0.75, 0.55, 0.38, 0.24):
            a_try = min(46.0, sea_dist * 0.72) * scale_try
            b_try = min(18.0, sea_dist * 0.34) * scale_try
            if a_try < 4.5:
                continue
            phis = np.linspace(0.0, 2.0 * np.pi, 16, endpoint=False)
            xs_chk = vx + np.cos(phis) * a_try * fwd_x + np.sin(phis) * b_try * right_x
            zs_chk = vz + np.cos(phis) * a_try * fwd_z + np.sin(phis) * b_try * right_z
            if np.any((xs_chk < x0 + 60.0) | (xs_chk > x1 - 60.0) | (zs_chk < y0 + 60.0) | (zs_chk > y1 - 60.0)):
                continue
            ok_sea = True
            for lx, lz in zip(xs_chk, zs_chk):
                lpx, lpy = world_to_px(float(lx), float(lz))
                if float(outside[lpy, lpx]) < 4.5:
                    ok_sea = False
                    break
            if ok_sea:
                cruise_a = round(a_try, 2)
                cruise_b = round(b_try, 2)
                break

        knot_speed = float(rng.uniform(2.0, 3.6)) if variant in cargo_variants else float(rng.uniform(1.4, 2.6))
        omega = float(np.clip(knot_speed / max(cruise_a, 12.0), 0.045, 0.14)) if cruise_a > 0.0 else 0.0
        if len(vessels) % 2 == 1:
            omega = -omega

        vessels.append({
            "x": round(vx, 3),
            "z": round(vz, 3),
            "kind": "vessel",
            "variant": variant,
            "rotation": round(heading, 4),
            "size": round(v_size, 3),
            "phase": round(float(rng.uniform(0.0, np.pi * 2.0)), 3),
            "cruise_a": cruise_a,
            "cruise_b": cruise_b,
            "speed": round(omega, 4),
        })
        vessel_pts.append((vx, vz))

    # Open-water cumulus cloud fronts (synoptic clusters over open sea > 130 units from coast)
    clouds: list[list[float]] = []
    sea_fronts: list[tuple[float, float]] = []
    for _ in range(5000):
        if len(sea_fronts) == 22:
            break
        fx = float(rng.uniform(x0 + 240.0, x1 - 240.0))
        fz = float(rng.uniform(y0 + 180.0, y1 - 180.0))
        px, py = world_to_px(fx, fz)
        if outside[py, px] < 138.0 or any((fx - sx) ** 2 + (fz - sz) ** 2 < 260.0 ** 2 for sx, sz in sea_fronts):
            continue
        sea_fronts.append((fx, fz))
    for _ in range(25000):
        if len(clouds) == 120:
            break
        if sea_fronts and rng.random() < 0.85:
            fx, fz = sea_fronts[int(rng.integers(0, len(sea_fronts)))]
            ang_f = float(rng.random() * np.pi * 2.0)
            dist_f = float(rng.uniform(0.0, 175.0))
            cx = float(np.clip(fx + np.cos(ang_f) * dist_f, x0 + 140.0, x1 - 140.0))
            cz = float(np.clip(fz + np.sin(ang_f) * dist_f * 0.65, y0 + 110.0, y1 - 110.0))
            csize = float(rng.uniform(0.58, 1.55) * (1.25 - 0.35 * dist_f / 175.0))
        else:
            cx = float(rng.uniform(x0 + 180.0, x1 - 180.0))
            cz = float(rng.uniform(y0 + 120.0, y1 - 120.0))
            csize = float(rng.uniform(0.65, 1.35))
        px, py = world_to_px(cx, cz)
        if outside[py, px] < 130.0 or any((cx - p[0]) ** 2 + (cz - p[1]) ** 2 < 46.0 ** 2 for p in clouds):
            continue
        clouds.append([
            round(cx, 3),
            round(cz, 3),
            round(csize, 3),
            round(float(rng.uniform(0.0, np.pi * 2.0)), 3),
            round(float(145 + (len(clouds) % 5) * 28 + rng.uniform(-10, 14)), 1),
        ])

    # High-altitude translucent monsoon cloud banks across archipelago skies (fade out at close city zoom)
    high_clouds: list[list[float]] = []
    high_fronts: list[tuple[float, float]] = []
    for _ in range(3000):
        if len(high_fronts) == 14:
            break
        fx = float(rng.uniform(x0 + 240.0, x1 - 240.0))
        fz = float(rng.uniform(y0 + 160.0, y1 - 160.0))
        px, py = world_to_px(fx, fz)
        if inside[py, px] < 5.0 and outside[py, px] > 60.0:
            continue
        if any((fx - sx) ** 2 + (fz - sz) ** 2 < 240.0 ** 2 for sx, sz in high_fronts):
            continue
        high_fronts.append((fx, fz))
    for _ in range(18000):
        if len(high_clouds) == 64:
            break
        if high_fronts:
            fx, fz = high_fronts[int(rng.integers(0, len(high_fronts)))]
            ang_f = float(rng.random() * np.pi * 2.0)
            dist_f = float(rng.uniform(0.0, 150.0))
            hx = float(np.clip(fx + np.cos(ang_f) * dist_f, x0 + 180.0, x1 - 180.0))
            hz = float(np.clip(fz + np.sin(ang_f) * dist_f * 0.65, y0 + 130.0, y1 - 130.0))
            hsize = float(rng.uniform(0.85, 1.95) * (1.2 - 0.3 * dist_f / 150.0))
        else:
            hx = float(rng.uniform(x0 + 220.0, x1 - 220.0))
            hz = float(rng.uniform(y0 + 140.0, y1 - 140.0))
            hsize = float(rng.uniform(0.95, 1.75))
        px, py = world_to_px(hx, hz)
        if inside[py, px] < 4.0 and outside[py, px] > 65.0:
            continue
        if any((hx - p[0]) ** 2 + (hz - p[1]) ** 2 < 54.0 ** 2 for p in high_clouds):
            continue
        high_clouds.append([
            round(hx, 3),
            round(hz, 3),
            round(hsize, 3),
            round(float(rng.uniform(0.0, np.pi * 2.0)), 3),
            round(float(255 + (len(high_clouds) % 4) * 34 + rng.uniform(-12, 16)), 1),
        ])

    counts = dict(Counter(p["kind"] for p in placements))
    counts["vessel"] = len(vessels)

    payload = {
        "schema": "nusantara.map_art/3",
        "seed": SEED,
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
        "field_bounds": [x0, y0, x1 - x0, y1 - y0],
        "field_size": [width, height],
        "field_channels": "R=land,G=sea_distance/180,B=inland_distance/90",
        "detail_channels": "R=urban_glow,G=biome_richness,B=artistic_relief",
        "meaning": "ARTISTIC_DECORATION; no measured elevation, land cover, settlement extent, shipping traffic or bathymetry",
        "build": {"numpy": np.__version__, "scipy": scipy.__version__},
        "counts": counts,
        "props": placements,
        "vessels": vessels,
        "clouds": clouds,
        "high_clouds": high_clouds,
    }
    (OUT / "diorama.json").write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
    print(
        f"Built coast/detail fields {width}x{height}: "
        f"{len(placements)} land props, {len(vessels)} vessels, "
        f"{len(clouds)} sea clouds, {len(high_clouds)} high clouds; canonical GIS unchanged"
    )
    print("Kind counts:", dict(sorted(counts.items())))


if __name__ == "__main__":
    build()
