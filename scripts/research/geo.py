"""Geometry helpers for validation and area diagnostics (stdlib only).

Area: polygons are projected to the ellipsoidal Lambert cylindrical equal-area
projection on WGS84 (x = a*lon, y = a*q(lat)/2, Snyder 1987 eq. 3-12), which is
exactly area-preserving on the ellipsoid, then measured with the shoelace
formula. Edges are straight in that projection rather than geodesics; at BIG
1:50.000 vertex density the difference is negligible (tested below 0.01 %).

Validity: structural checks (closed rings, >= 4 positions, finite coordinates
inside an Indonesia bounding box) plus a grid-indexed segment-crossing test.
A *proper* crossing between two segments (interiors intersect at one point)
means a self-intersecting ring, or two polygons overlapping. Shared borders
(identical or collinear segments) and touching at vertices are not crossings.
"""

from __future__ import annotations

import math
from collections import defaultdict

WGS84_A = 6378137.0
WGS84_E2 = 0.00669437999014
_E = math.sqrt(WGS84_E2)

# Generous Indonesia envelope incl. outer islands (lon 94..142, lat -12..7)
INDONESIA_BBOX = (94.0, -12.0, 142.0, 7.0)


def _q(lat_rad: float) -> float:
    s = math.sin(lat_rad)
    es = _E * s
    return (1 - WGS84_E2) * (s / (1 - WGS84_E2 * s * s) - (1 / (2 * _E)) * math.log((1 - es) / (1 + es)))


def _ring_area_m2(ring) -> float:
    if len(ring) < 4:
        return 0.0
    lon0 = ring[0][0]
    pts = [(WGS84_A * math.radians(c[0] - lon0), WGS84_A * _q(math.radians(c[1])) / 2) for c in ring]
    y0 = pts[0][1]
    s = 0.0
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        s += x1 * (y2 - y0) - x2 * (y1 - y0)
    return abs(s) / 2


def polygons_of(geom: dict):
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon":
        return geom["coordinates"]
    raise ValueError(f"not a polygon geometry: {geom['type']}")


def area_km2(geom: dict) -> float:
    total = 0.0
    for poly in polygons_of(geom):
        total += _ring_area_m2(poly[0]) - sum(_ring_area_m2(h) for h in poly[1:])
    return total / 1e6


def vertex_count(geom: dict) -> int:
    return sum(len(r) for p in polygons_of(geom) for r in p)


def structural_problems(geom: dict | None, bbox=INDONESIA_BBOX) -> list[str]:
    if not geom:
        return ["null geometry"]
    probs = []
    try:
        polys = polygons_of(geom)
    except ValueError as e:
        return [str(e)]
    if not polys:
        probs.append("empty geometry")
    for pi, poly in enumerate(polys):
        if not poly:
            probs.append(f"polygon {pi}: no rings")
        for ri, ring in enumerate(poly):
            if len(ring) < 4:
                probs.append(f"polygon {pi} ring {ri}: {len(ring)} positions")
                continue
            if ring[0][:2] != ring[-1][:2]:
                probs.append(f"polygon {pi} ring {ri}: not closed")
            for c in ring:
                lon, lat = c[0], c[1]
                if not (math.isfinite(lon) and math.isfinite(lat)):
                    probs.append(f"polygon {pi} ring {ri}: non-finite coordinate")
                    break
                if not (bbox[0] <= lon <= bbox[2] and bbox[1] <= lat <= bbox[3]):
                    probs.append(f"polygon {pi} ring {ri}: coordinate outside bbox ({lon}, {lat})")
                    break
            if _ring_area_m2(ring) == 0.0:
                probs.append(f"polygon {pi} ring {ri}: zero area")
    return probs


def _orient(ax, ay, bx, by, cx, cy) -> float:
    return (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)


def _proper_cross(p1, p2, p3, p4) -> bool:
    d1 = _orient(*p3, *p4, *p1)
    d2 = _orient(*p3, *p4, *p2)
    d3 = _orient(*p1, *p2, *p3)
    d4 = _orient(*p1, *p2, *p4)
    return ((d1 > 0 > d2) or (d1 < 0 < d2)) and ((d3 > 0 > d4) or (d3 < 0 < d4))


def find_crossings(features: list[tuple[str, dict]], cell_deg: float = 0.05, limit: int = 200):
    """Return up to `limit` proper segment crossings across all rings of all features.

    Each item: (feature_id_a, feature_id_b, (lon, lat) approx location).
    Same-feature hits are self-intersections; different-feature hits are overlaps.
    """
    segs = []
    for fid, geom in features:
        for poly in polygons_of(geom):
            for ring in poly:
                for a, b in zip(ring, ring[1:]):
                    if a != b:
                        segs.append((fid, (a[0], a[1]), (b[0], b[1])))
    grid = defaultdict(list)
    inv = 1.0 / cell_deg
    for i, (_, a, b) in enumerate(segs):
        x0, x1 = sorted((a[0], b[0]))
        y0, y1 = sorted((a[1], b[1]))
        for gx in range(int(math.floor(x0 * inv)), int(math.floor(x1 * inv)) + 1):
            for gy in range(int(math.floor(y0 * inv)), int(math.floor(y1 * inv)) + 1):
                grid[(gx, gy)].append(i)
    found, seen = [], set()
    for bucket in grid.values():
        n = len(bucket)
        for ii in range(n):
            i = bucket[ii]
            fa, a1, a2 = segs[i]
            ax0, ax1 = (a1[0], a2[0]) if a1[0] <= a2[0] else (a2[0], a1[0])
            ay0, ay1 = (a1[1], a2[1]) if a1[1] <= a2[1] else (a2[1], a1[1])
            for jj in range(ii + 1, n):
                j = bucket[jj]
                fb, b1, b2 = segs[j]
                if max(b1[0], b2[0]) < ax0 or min(b1[0], b2[0]) > ax1 or \
                   max(b1[1], b2[1]) < ay0 or min(b1[1], b2[1]) > ay1:
                    continue
                if a1 in (b1, b2) or a2 in (b1, b2):
                    continue
                if _proper_cross(a1, a2, b1, b2):
                    key = (min(i, j), max(i, j))
                    if key in seen:
                        continue
                    seen.add(key)
                    found.append((fa, fb, ((a1[0] + a2[0]) / 2, (a1[1] + a2[1]) / 2)))
                    if len(found) >= limit:
                        return found
    return found


def interior_point(polygon) -> tuple[float, float]:
    """A point strictly inside `polygon` (outer ring + holes), kept far from the boundary:
    over several horizontal scanlines, the midpoint of the WIDEST inside interval.
    Using every ring's crossings keeps the point out of holes (even-odd rule). A point
    far from the boundary stays inside after small boundary moves (e.g. simplification),
    which the first-interval choice did not guarantee."""
    ys = [c[1] for c in polygon[0]]
    y0, y1 = min(ys), max(ys)
    best = None
    for frac in (0.5, 0.37, 0.63, 0.21, 0.79, 0.11, 0.89, 0.3, 0.7):
        y = y0 + (y1 - y0) * frac
        xs = []
        for ring in polygon:
            for a, b in zip(ring, ring[1:]):
                if (a[1] > y) != (b[1] > y):
                    xs.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            w = xs[i + 1] - xs[i]
            if w > 0 and (best is None or w > best[0]):
                best = (w, ((xs[i] + xs[i + 1]) / 2, y))
    return best[1] if best else (polygon[0][0][0], polygon[0][0][1])  # degenerate ring


def point_in_polygon(pt, polygon) -> bool:
    """Even-odd ray casting over outer ring and holes."""
    x, y = pt
    inside = False
    for ring in polygon:
        for a, b in zip(ring, ring[1:]):
            if (a[1] > y) != (b[1] > y) and x < a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]):
                inside = not inside
    return inside


def find_containment_overlaps(features: list[tuple[str, dict]], limit: int = 200):
    """Overlaps that segment-crossing tests cannot see: a part of one feature lying wholly
    inside another feature (e.g. an enclave whose surrounding hole collapsed).
    Returns [(inner_feature_id, containing_feature_id, point)]."""
    parts = []  # (fid, polygon, bbox)
    for fid, geom in features:
        for poly in polygons_of(geom):
            xs = [c[0] for c in poly[0]]
            ys = [c[1] for c in poly[0]]
            parts.append((fid, poly, (min(xs), min(ys), max(xs), max(ys))))
    cell = 0.25
    grid = defaultdict(list)
    for i, (_, _, bb) in enumerate(parts):
        for gx in range(math.floor(bb[0] / cell), math.floor(bb[2] / cell) + 1):
            for gy in range(math.floor(bb[1] / cell), math.floor(bb[3] / cell) + 1):
                grid[(gx, gy)].append(i)
    found = []
    for fid, poly, _ in parts:
        pt = interior_point(poly)
        if not point_in_polygon(pt, poly):
            continue  # degenerate sliver; structural checks cover it
        for j in grid.get((math.floor(pt[0] / cell), math.floor(pt[1] / cell)), ()):
            ofid, opoly, obb = parts[j]
            if ofid == fid or not (obb[0] <= pt[0] <= obb[2] and obb[1] <= pt[1] <= obb[3]):
                continue
            if point_in_polygon(pt, opoly):
                found.append((fid, ofid, pt))
                if len(found) >= limit:
                    return found
                break
    return found


def vertex_adjacency(features: list[tuple[str, dict]], quantum: float = 1e-6) -> set[tuple[str, str]]:
    """Pairs of features sharing at least one vertex (coordinates quantized to `quantum` deg)."""
    # Every owner of a vertex must be kept: at a junction of three or more features,
    # remembering only the first owner would miss the pairs among the others.
    owners: dict[tuple[int, int], set[str]] = defaultdict(set)
    inv = 1.0 / quantum
    for fid, geom in features:
        for poly in polygons_of(geom):
            for ring in poly:
                for c in ring:
                    owners[(round(c[0] * inv), round(c[1] * inv))].add(fid)
    pairs = set()
    for fids in owners.values():
        if len(fids) > 1:
            fl = sorted(fids)
            pairs.update((a, b) for i, a in enumerate(fl) for b in fl[i + 1:])
    return pairs
