"""Audit what happens to every raw source polygon part (island/mainland piece) in each LOD.

Region identity surviving (514/514) does not prove every island stays visible, so each of
the raw source parts is classified per LOD by locating an interior point of the source
part among the output parts of the SAME region:

  distinct   the point lies in an output part that contains no other source part's point
  absorbing  the point lies in an output part shared with other source parts, and this is
             the largest of them (it is still drawn; smaller parts were joined to it)
  merged     the point lies in an output part shared with other source parts and is not
             the largest of them (joined to
             a neighbouring island or the coast by simplification/cleaning, or touching
             in the source)
  deformed   the point lies in no output part, but an output part of the region matches the
             source part's bbox with IoU >= 0.5: drawn as its own shape, distorted (e.g.
             simplification cut a narrow lobe the point sat in); IoU and area ratio kept
  displaced  none of the above, but an output part of the region is within
             1.5 x the simplification interval (part collapsed/shifted: still drawn nearby)
  lost       none of the above

A part is "noticeable" when its length (larger bbox extent) is >= 4 px AND its mean width
(area / length) is >= 1 px at the reference scale; the selection rule requires that no
noticeable part is displaced or lost. A part is "visible at the LOD" when its larger bbox extent is >= 1 px at the LOD's
reference scale (lod_tolerance_selection.json). The audit flags visible parts that are
merged, displaced or lost (not drawn as their own shape) and lists the largest ones.

Writes research/reports/island_component_audit.json
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, utc_now_iso
from geo import area_km2, interior_point, point_in_polygon, polygons_of

REF_M_PER_PX = {"lod1": 1250, "lod2": 190, "lod3": 50}
SIZE_BINS = [(0, 100), (100, 1_000), (1_000, 10_000), (10_000, 100_000), (100_000, 1_000_000),
             (1_000_000, 10_000_000), (10_000_000, float("inf"))]  # m2


def bin_label(a):
    for lo, hi in SIZE_BINS:
        if lo <= a < hi:
            return f"{lo:g}-{hi:g} m2" if hi != float("inf") else f">={lo:g} m2"


def extent_m(bb):
    lat = (bb[1] + bb[3]) / 2
    return max((bb[2] - bb[0]) * 111_320 * math.cos(math.radians(lat)), (bb[3] - bb[1]) * 110_574)


def source_parts(snapshot: str) -> list[dict]:
    cache = REPO_ROOT / "data" / "processed" / "geography" / snapshot / "fullres_parts.json"
    pages = sorted((DATA_RAW / "SRC-0001" / snapshot).glob("kabkota_geom_*.geojson"))
    key = [json.loads(Path(str(p) + ".meta.json").read_text())["sha256"] for p in pages]
    if cache.exists():
        doc = json.loads(cache.read_text())
        if doc["raw_page_sha256"] == key:
            return doc["parts"]
    reg = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))
    o2r = {int(o): r["region_id"] for r in reg["regions"] for o in r["big_objectids"].split(";")}
    parts = []
    for page in pages:
        for f in json.loads(page.read_text())["features"]:
            rid = o2r.get(f["properties"]["OBJECTID"])
            if rid is None:
                continue  # TIPADM=6 fragments are audited by feature count in the validator
            for poly in polygons_of(f["geometry"]):
                xs = [c[0] for c in poly[0]]
                ys = [c[1] for c in poly[0]]
                pt = interior_point(poly)
                parts.append({"region_id": rid, "area_m2": area_km2({"type": "Polygon", "coordinates": poly}) * 1e6,
                              "bbox": [min(xs), min(ys), max(xs), max(ys)],
                              "pt": list(pt), "pt_ok": point_in_polygon(pt, poly)})
    cache.write_text(json.dumps({"raw_page_sha256": key, "parts": parts}) + "\n")
    return parts


def audit_lod(lod_dir: Path, parts: list[dict]) -> dict:
    lod = lod_dir.name.split("_")[0]
    interval = json.loads((lod_dir / "build_log.json").read_text())["interval_m"]
    pad = interval * 1.5 / 111_320
    out = defaultdict(list)  # region -> [(polygon, bbox)]
    for f in json.loads((lod_dir / "kabkota.json").read_text())["features"]:
        for poly in polygons_of(f["geometry"]):
            xs = [c[0] for c in poly[0]]
            ys = [c[1] for c in poly[0]]
            out[f["properties"]["region_id"]].append((poly, (min(xs), min(ys), max(xs), max(ys))))

    status, owner = [], {}
    for i, p in enumerate(parts):
        x, y = p["pt"]
        hit = None
        for j, (poly, bb) in enumerate(out[p["region_id"]]):
            if bb[0] <= x <= bb[2] and bb[1] <= y <= bb[3] and point_in_polygon((x, y), poly):
                hit = j
                break
        if hit is not None:
            status.append(("in", hit))
            owner.setdefault((p["region_id"], hit), []).append(i)
        else:
            sb = p["bbox"]
            best_iou, best_j = 0.0, None
            for j, (_, bb) in enumerate(out[p["region_id"]]):
                iw = min(sb[2], bb[2]) - max(sb[0], bb[0])
                ih = min(sb[3], bb[3]) - max(sb[1], bb[1])
                if iw > 0 and ih > 0:
                    inter = iw * ih
                    union = (sb[2] - sb[0]) * (sb[3] - sb[1]) + (bb[2] - bb[0]) * (bb[3] - bb[1]) - inter
                    if union > 0 and inter / union > best_iou:
                        best_iou, best_j = inter / union, j
            if best_iou >= 0.5:
                poly = out[p["region_id"]][best_j][0]
                status.append(("deformed", {"iou": best_iou,
                                            "area_ratio": area_km2({"type": "Polygon", "coordinates": poly}) * 1e6
                                            / p["area_m2"] if p["area_m2"] > 0 else None}))
                continue
            near = any(not (sb[2] + pad < bb[0] or bb[2] + pad < sb[0] or sb[3] + pad < bb[1] or bb[3] + pad < sb[1])
                       for _, bb in out[p["region_id"]])
            status.append(("displaced" if near else "lost", None))

    ref = REF_M_PER_PX[lod]
    counts = Counter()
    by_bin = defaultdict(Counter)
    visible_not_distinct = []
    deformed = []
    for i, p in enumerate(parts):
        kind, j = status[i]
        if kind == "in":
            group = owner[(p["region_id"], j)]
            if len(group) == 1:
                kind = "distinct"
            else:
                kind = "absorbing" if max(group, key=lambda k: parts[k]["area_m2"]) == i else "merged"
        counts[kind] += 1
        by_bin[bin_label(p["area_m2"])][kind] += 1
        ext = extent_m(p["bbox"])
        if kind == "deformed":
            deformed.append({"area_m2": p["area_m2"], "extent_m": ext, **j})
        if ext >= ref and kind not in ("distinct", "absorbing", "deformed"):
            entry = {"region_id": p["region_id"], "status": kind, "area_m2": round(p["area_m2"], 1),
                     "extent_m": round(ext, 1), "at": [round(v, 5) for v in p["pt"]]}
            if kind == "merged":
                sib = [parts[k] for k in owner[(p["region_id"], status[i][1])] if k != i]
                entry["merged_with_largest_area_m2"] = round(max(s["area_m2"] for s in sib), 1)
                entry["merged_part_count"] = len(sib) + 1
            visible_not_distinct.append(entry)
    visible_not_distinct.sort(key=lambda e: -e["area_m2"])
    vis = sum(1 for p in parts if extent_m(p["bbox"]) >= ref)
    return {
        "lod": lod, "interval_m": interval, "reference_m_per_px": ref,
        "source_parts": len(parts), "status_counts": dict(counts),
        "by_size_bin": {k: dict(v) for k, v in sorted(by_bin.items(), key=lambda kv: float(kv[0].split("-")[0].lstrip(">=").split(" ")[0]))},
        "visible_parts_at_reference_scale": vis,
        "visible_parts_not_drawn_on_their_own": len(visible_not_distinct),
        "visible_parts_lost": sum(1 for e in visible_not_distinct if e["status"] == "lost"),
        # selection-rule criterion (lod_tolerance_selection.json): NOTICEABLE parts - length
        # >= 4 px AND mean width (area / length) >= 1 px at the reference scale - must not be
        # displaced or lost. Length alone counted hairline sandbars/spits (< 1 px wide) as islands.
        "noticeable_parts_displaced_or_lost": [e for e in visible_not_distinct
                                               if e["status"] in ("displaced", "lost") and e["extent_m"] >= 4 * ref
                                               and e["area_m2"] / e["extent_m"] >= ref],
        "noticeable_parts": sum(1 for p in parts if extent_m(p["bbox"]) >= 4 * ref
                                and p["area_m2"] / max(extent_m(p["bbox"]), 1e-9) >= ref),
        "visible_not_drawn_on_their_own_status_counts": dict(Counter(e["status"] for e in visible_not_distinct)),
        "largest_visible_not_drawn_on_their_own": visible_not_distinct[:40],
        "regions_with_any_part": len(out),
        "deformed_summary": {
            "count": len(deformed),
            "visible_count": sum(1 for d in deformed if d["extent_m"] >= ref),
            "area_ratio_median": statistics.median(d["area_ratio"] for d in deformed) if deformed else None,
            "area_ratio_p05": sorted(d["area_ratio"] for d in deformed)[int(0.05 * (len(deformed) - 1))] if deformed else None,
            "iou_median": statistics.median(d["iou"] for d in deformed) if deformed else None,
            "largest": sorted(({k: round(v, 3) for k, v in d.items()} for d in deformed),
                              key=lambda d: -d["area_m2"])[:10],
        },
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--render-root", help="directory holding lod1/lod2/lod3 (default: production render dir)")
    ap.add_argument("--lods", nargs="*", default=["lod1", "lod2", "lod3"])
    ap.add_argument("--report", default=str(REPO_ROOT / "research" / "reports" / "island_component_audit.json"))
    args = ap.parse_args()
    parts = source_parts(args.snapshot)
    render = Path(args.render_root) if args.render_root else (
        REPO_ROOT / "data" / "processed" / "geography" / args.snapshot / "render")
    report = {"snapshot_id": args.snapshot, "built_at": utc_now_iso(), "source_parts": len(parts),
              "source_parts_without_reliable_interior_point": sum(1 for p in parts if not p["pt_ok"]),
              "source_size_bins": dict(Counter(bin_label(p["area_m2"]) for p in parts)),
              "lods": {}}
    for lod in args.lods:
        res = audit_lod(render / lod, parts)
        report["lods"][lod] = res
        print(lod, res["status_counts"], "| visible:", res["visible_parts_at_reference_scale"],
              "visible but merged/displaced/lost:", res["visible_not_drawn_on_their_own_status_counts"],
              "regions:", res["regions_with_any_part"])
    Path(args.report).write_text(
        json.dumps(report, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
