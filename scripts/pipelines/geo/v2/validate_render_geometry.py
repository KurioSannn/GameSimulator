"""Validate render-geometry LODs against the registry and the raw full-resolution source.

Checks per LOD (hard = build-breaking):
  hard  kabkota: 514 features, region_id set == registry, codes/parent/level/name/group preserved
  hard  provinsi: 38 features, ids == registry provinces, nav group consistent with its kab/kota
  hard  fragments: 21 features (BIG TIPADM=6)
  hard  structural validity (closed rings, >= 4 positions, finite, inside Indonesia bbox, non-zero area)
  hard  no proper segment crossings in kabkota+fragments (self-intersections or overlaps)
  hard  no containment overlaps (a part lying wholly inside another feature)
  hard  adjacency preserved: neighbour pairs (shared vertex at 1e-6 deg) == raw source
  hard  island survival: every raw source part is represented by an output part of the same
        region (bbox within the simplification interval)
  soft  per-region area error vs raw full-res area (reported; thresholds per LOD in report)
  soft  no proper segment crossings in provinsi

Writes research/reports/render_geometry_validation.json (merged per LOD) and a
full-res metrics cache data/processed/geography/<snap>/fullres_region_metrics.json.
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, sha256_file, utc_now_iso
from geo import (area_km2, find_containment_overlaps, find_crossings, polygons_of, structural_problems,
                 vertex_adjacency, vertex_count)

NAV_GROUPS = REPO_ROOT / "data" / "design" / "navigation_groups.json"


def bbox_of(ring_or_poly):
    xs = [c[0] for c in ring_or_poly]
    ys = [c[1] for c in ring_or_poly]
    return (min(xs), min(ys), max(xs), max(ys))


def fullres_metrics(snapshot: str, registry: dict) -> dict:
    """Per-region full-res area and source part bboxes, cached and keyed by raw checksums."""
    raw = DATA_RAW / "SRC-0001" / snapshot
    pages = sorted(raw.glob("kabkota_geom_*.geojson"))
    cache = REPO_ROOT / "data" / "processed" / "geography" / snapshot / "fullres_region_metrics.json"
    key = [json.loads(Path(str(p) + ".meta.json").read_text())["sha256"] for p in pages]
    if cache.exists():
        doc = json.loads(cache.read_text())
        if doc.get("raw_page_sha256") == key:
            return doc
    oid_to_region = {}
    for r in registry["regions"]:
        for o in r["big_objectids"].split(";"):
            oid_to_region[int(o)] = r["region_id"]
    regions = defaultdict(lambda: {"area_km2": 0.0, "vertices": 0, "parts": []})
    fragments = 0
    for page in pages:
        for f in json.loads(page.read_text())["features"]:
            oid = f["properties"]["OBJECTID"]
            if oid not in oid_to_region:
                fragments += 1
                continue
            m = regions[oid_to_region[oid]]
            m["area_km2"] += area_km2(f["geometry"])
            m["vertices"] += vertex_count(f["geometry"])
            m["parts"] += [list(bbox_of(p[0])) for p in polygons_of(f["geometry"])]
    doc = {"snapshot_id": snapshot, "built_at": utc_now_iso(), "raw_page_sha256": key,
           "fragment_features": fragments, "regions": dict(regions)}
    cache.write_text(json.dumps(doc) + "\n")
    return doc


def bbox_hit(a, b, pad):
    return not (a[2] + pad < b[0] or b[2] + pad < a[0] or a[3] + pad < b[1] or b[3] + pad < a[1])


def validate_lod(lod_dir: Path, registry: dict, groups: dict, full: dict) -> dict:
    log = json.loads((lod_dir / "build_log.json").read_text())
    interval_m = log["interval_m"]
    pad_deg = interval_m / 111_320 * 1.5
    kab = json.loads((lod_dir / "kabkota.json").read_text())["features"]
    prov = json.loads((lod_dir / "provinsi.json").read_text())["features"]
    frag = json.loads((lod_dir / "fragments.json").read_text())["features"]
    checks = []

    def check(name, ok, detail=None, hard=True):
        checks.append({"check": name, "passed": bool(ok), "hard": hard, "detail": detail})

    reg = {r["region_id"]: r for r in registry["regions"]}
    regp = {p["region_id"]: p for p in registry["provinces"]}
    ids = [f["properties"].get("region_id") for f in kab]
    check("kabkota feature count == 514", len(kab) == 514, len(kab))
    check("kabkota region_id unique", len(ids) == len(set(ids)), len(ids) - len(set(ids)))
    check("kabkota ids == registry", set(ids) == set(reg),
          {"missing": sorted(set(reg) - set(ids)), "extra": sorted(set(ids) - set(reg))})
    prop_diff = []
    for f in kab:
        p, r = f["properties"], reg.get(f["properties"].get("region_id"))
        if not r:
            continue
        expect = {"kode_bps": r["kode_bps"], "parent_region_id": r["parent_region_id"],
                  "province_kode_bps": r["province_kode_bps"], "region_level": r["region_level"],
                  "name": r["name"], "nav_group_key": groups[r["parent_region_id"]]}
        bad = {k: (p.get(k), v) for k, v in expect.items() if p.get(k) != v}
        if bad:
            prop_diff.append({"region_id": r["region_id"], "diff": bad})
    check("kabkota codes/parent/level/name/group preserved", not prop_diff, prop_diff[:20])

    pids = [f["properties"].get("region_id") for f in prov]
    check("provinsi feature count == 38", len(prov) == 38, len(prov))
    check("provinsi ids == registry", set(pids) == set(regp),
          {"missing": sorted(set(regp) - set(pids)), "extra": sorted(set(pids) - set(regp))})
    pbad = [f["properties"]["region_id"] for f in prov
            if f["properties"].get("nav_group_key") != groups.get(f["properties"].get("region_id"))
            or f["properties"].get("kode_bps") != regp.get(f["properties"].get("region_id"), {}).get("kode_bps")]
    check("provinsi codes and nav group preserved", not pbad, pbad)
    check("fragments feature count == 21", len(frag) == 21, len(frag))

    struct = {}
    for layer, feats, key in (("kabkota", kab, "region_id"), ("provinsi", prov, "region_id"),
                              ("fragments", frag, "fragment_id")):
        for f in feats:
            probs = structural_problems(f["geometry"])
            if probs:
                struct[f"{layer}:{f['properties'].get(key)}"] = probs[:5]
    check("structural validity (all layers)", not struct, dict(list(struct.items())[:20]))

    # grid cell ~2x the typical segment length keeps buckets small at every LOD
    cell = max(2 * interval_m / 111_320, 0.0005)
    crossings = find_crossings([(f["properties"]["region_id"], f["geometry"]) for f in kab] +
                               [(f["properties"]["fragment_id"], f["geometry"]) for f in frag], cell_deg=cell)
    check("no self-intersections/overlaps in kabkota+fragments", not crossings,
          [{"a": a, "b": b, "at": [round(x, 5) for x in pt]} for a, b, pt in crossings[:30]])
    all_feats = ([(f["properties"]["region_id"], f["geometry"]) for f in kab] +
                 [(f["properties"]["fragment_id"], f["geometry"]) for f in frag])
    contained = find_containment_overlaps(all_feats)
    check("no containment overlaps (part of one feature inside another)", not contained,
          [{"inner": a, "container": b, "at": [round(x, 5) for x in pt]} for a, b, pt in contained[:30]])
    adj_path = REPO_ROOT / "data" / "processed" / "geography" / full["snapshot_id"] / "fullres_adjacency.json"
    if adj_path.exists():
        src_pairs = {tuple(p) for p in json.loads(adj_path.read_text())["pairs"]}
        lod_pairs = vertex_adjacency(all_feats)
        lost_pairs = sorted(src_pairs - lod_pairs)
        new_pairs = sorted(lod_pairs - src_pairs)
        check("adjacency preserved (no neighbour pair lost or gained vs raw source)",
              not lost_pairs and not new_pairs,
              {"source_pairs": len(src_pairs), "lod_pairs": len(lod_pairs),
               "lost": lost_pairs[:30], "gained": new_pairs[:30]})
    else:
        check("adjacency preserved (no neighbour pair lost or gained vs raw source)", False,
              "fullres_adjacency.json missing: run compute_source_adjacency.py")
    pcross = find_crossings([(f["properties"]["region_id"], f["geometry"]) for f in prov], cell_deg=cell)
    check("no self-intersections/overlaps in provinsi", not pcross,
          [{"a": a, "b": b, "at": [round(x, 5) for x in pt]} for a, b, pt in pcross[:30]], hard=False)

    # island survival + area error
    lost, area_err, out_parts, src_parts = [], {}, 0, 0
    for f in kab:
        rid = f["properties"]["region_id"]
        m = full["regions"].get(rid)
        if not m:
            continue
        boxes = [bbox_of(p[0]) for p in polygons_of(f["geometry"])]
        out_parts += len(boxes)
        for sb in m["parts"]:
            src_parts += 1
            if not any(bbox_hit(sb, ob, pad_deg) for ob in boxes):
                lost.append({"region_id": rid, "bbox": [round(x, 5) for x in sb]})
        area_err[rid] = area_km2(f["geometry"]) / m["area_km2"] - 1
    missing_full = sorted(set(reg) - set(full["regions"]))
    check("full-res source available for every region", not missing_full, missing_full)
    check("island survival (every source part represented in its own region)", not lost,
          {"lost": len(lost), "examples": lost[:20]})
    errs = list(area_err.values())
    abs_errs = sorted(abs(e) for e in errs)
    worst = sorted(area_err.items(), key=lambda kv: -abs(kv[1]))[:10]
    small = [rid for rid, m in full["regions"].items() if m["area_km2"] < 50]

    sizes = {n: (lod_dir / n).stat().st_size for n in ("kabkota.json", "provinsi.json", "fragments.json")}
    return {
        "lod": lod_dir.name, "interval_m": interval_m, "validated_at": utc_now_iso(),
        "mapshaper_stats": log["stats"],
        "counts": {"kabkota": len(kab), "provinsi": len(prov), "fragments": len(frag),
                   "kabkota_output_parts": out_parts, "source_parts": src_parts},
        "vertices": {"kabkota": sum(vertex_count(f["geometry"]) for f in kab),
                     "provinsi": sum(vertex_count(f["geometry"]) for f in prov)},
        "bytes": sizes,
        "area_error": {"median_abs": statistics.median(abs_errs) if abs_errs else None,
                       "p95_abs": abs_errs[int(0.95 * (len(abs_errs) - 1))] if abs_errs else None,
                       "max_abs": abs_errs[-1] if abs_errs else None,
                       "worst": [{"region_id": k, "rel_error": v} for k, v in worst],
                       "small_regions_lt_50km2_max_abs":
                           max((abs(area_err[r]) for r in small if r in area_err), default=None)},
        "file_sha256": {n: sha256_file(lod_dir / n) for n in sizes},
        "checks": checks,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("lod_dirs", nargs="+")
    ap.add_argument("--report", default=str(REPO_ROOT / "research" / "reports" / "render_geometry_validation.json"))
    args = ap.parse_args()

    registry = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))
    groups = {p: g["group_key"] for g in json.loads(NAV_GROUPS.read_text())["groups"] for p in g["provinces"]}
    full = fullres_metrics(args.snapshot, registry)
    raw_bytes = sum(p.stat().st_size for p in (DATA_RAW / "SRC-0001" / args.snapshot).glob("kabkota_geom_*.geojson"))
    raw_vertices = sum(m["vertices"] for m in full["regions"].values())

    report_path = Path(args.report)
    report = json.loads(report_path.read_text()) if report_path.exists() else {}
    report.update({"snapshot_id": args.snapshot, "raw_source": {"bytes": raw_bytes, "kabkota_vertices": raw_vertices,
                                                                "regions_with_geometry": len(full["regions"])}})
    report.setdefault("lods", {})
    failed = False
    for d in args.lod_dirs:
        res = validate_lod(Path(d), registry, groups, full)
        report["lods"][res["lod"]] = res
        hard_fail = [c for c in res["checks"] if c["hard"] and not c["passed"]]
        failed |= bool(hard_fail)
        print(f"== {res['lod']} interval={res['interval_m']:g}m vertices={res['vertices']} bytes={res['bytes']}")
        print(f"   parts out/src={res['counts']['kabkota_output_parts']}/{res['counts']['source_parts']} "
              f"area_err median={res['area_error']['median_abs']:.5f} p95={res['area_error']['p95_abs']:.5f} "
              f"max={res['area_error']['max_abs']:.5f}")
        for c in res["checks"]:
            flag = "PASS" if c["passed"] else ("FAIL" if c["hard"] else "WARN")
            if flag != "PASS":
                print(f"   [{flag}] {c['check']}: {json.dumps(c['detail'])[:400]}")
        print(f"   {sum(c['passed'] for c in res['checks'])}/{len(res['checks'])} checks passed")
    if len(report["lods"]) > 1:
        idsets = {}
        for name, res in report["lods"].items():
            p = Path(args.lod_dirs[0]).parent / name / "kabkota.json"
            if p.exists():
                idsets[name] = sorted(f["properties"]["region_id"] for f in json.loads(p.read_text())["features"])
        report["cross_lod_id_sets_identical"] = len({json.dumps(v) for v in idsets.values()}) <= 1
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
