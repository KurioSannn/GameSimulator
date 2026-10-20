"""Build render-geometry levels of detail (LODs) from raw BIG polygons with mapshaper.

Raw source (never modified): data/raw/SRC-0001/<snap>/kabkota_geom_*.geojson
Derived output (per LOD):     data/processed/geography/<snap>/render/<lod>/
    kabkota.json    514 features, one (multi)polygon per kab/kota
    provinsi.json   38 features, dissolved from the simplified kab/kota layer
    fragments.json  21 BIG TIPADM=6 unallocated fragments (render-only, D-014)
    build_log.json  exact mapshaper command, version, stats and messages

Pipeline per LOD (one mapshaper process, so every layer shares one arc topology):
  1. merge raw pages; split TIPADM=6 fragments into their own layer
  2. dissolve kab/kota by KDPKAB (merges 'Wilayah terapung' parts into their region)
  3. join registry attributes (region_id, kode_bps, parent, level, name, nav group)
  4. explode to single parts, so keep-shapes protects every island, not only the
     largest ring of each region
  5. simplify (Douglas-Peucker by default - displacement bounded by the interval; weighted
     Visvalingam was rejected, see D-015 - spherical, interval=<m>, keep-shapes, repair on)
  6. write the simplified parts, then re-import them (second mapshaper pass): mapshaper
     simplification is non-destructive, so repairs must run on the baked geometry. Pass B:
     -clean (gap-width=0), re-dissolve parts by region_id, round inside mapshaper
     (-snap precision fix-geometry), -clean again, dissolve provinces from the result
  7. write GeoJSON (RFC 7946) at 1e-6 deg precision (~0.11 m). Measured on trial
     builds: 1e-3 deg collapsed ~46 % of island parts; 1e-5 deg created segment
     crossings between near-touching tiny islands (0 crossings unrounded and at 1e-6)

Usage:
  python3 scripts/research/build_render_geometry.py --lod lod1 --interval 1000   # production (D-015)
  python3 scripts/research/build_render_geometry.py --lod lod2 --interval 100
  python3 scripts/research/build_render_geometry.py --lod lod3 --interval 40
  python3 scripts/research/build_render_geometry.py --lod lod1_2000 --interval 2000 --out-root <dir>  # candidate
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, utc_now_iso

MAPSHAPER = REPO_ROOT / "tools" / "geo" / "node_modules" / "mapshaper" / "bin" / "mapshaper"
NAV_GROUPS = REPO_ROOT / "data" / "design" / "navigation_groups.json"
PRECISION = "0.000001"
KAB_FIELDS = "region_id,kode_bps,parent_region_id,province_kode_bps,region_level,name,nav_group_key"
PROV_FIELDS = "region_id,kode_bps,name,nav_group_key"


def load_nav_groups() -> dict[str, str]:
    """province region_id -> group_key; hard-fails unless all 38 provinces are in exactly one group."""
    doc = json.loads(NAV_GROUPS.read_text(encoding="utf-8"))
    provinces = {p["region_id"] for p in json.loads(
        (DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))["provinces"]}
    member: dict[str, str] = {}
    for g in doc["groups"]:
        for pid in g["provinces"]:
            if pid in member:
                raise SystemExit(f"province {pid} is in both {member[pid]} and {g['group_key']}")
            member[pid] = g["group_key"]
    if len(doc["groups"]) != 7:
        raise SystemExit(f"expected 7 navigation groups, found {len(doc['groups'])}")
    if set(member) != provinces:
        raise SystemExit(f"navigation groups mismatch: missing={sorted(provinces - set(member))} "
                         f"unknown={sorted(set(member) - provinces)}")
    return member


def write_join_tables(work: Path, member: dict[str, str]) -> tuple[Path, Path]:
    reg = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))
    work.mkdir(parents=True, exist_ok=True)
    kab, prov = work / "join_kabkota.csv", work / "join_provinsi.csv"
    with kab.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["KDPKAB"] + KAB_FIELDS.split(","))
        for r in reg["regions"]:
            w.writerow([r["region_id"], r["region_id"], r["kode_bps"], r["parent_region_id"],
                        r["province_kode_bps"], r["region_level"], r["name"], member[r["parent_region_id"]]])
    with prov.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["parent_region_id"] + PROV_FIELDS.split(","))
        for p in reg["provinces"]:
            w.writerow([p["region_id"], p["region_id"], p["kode_bps"], p["name"], member[p["region_id"]]])
    return kab, prov


def parse_stats(text: str) -> dict:
    def num(pattern, cast=float):
        m = re.search(pattern, text)
        return cast(m.group(1).replace(",", "")) if m else None
    q = re.search(r"Displacement statistics.*?Quartiles: ([\d.]+), ([\d.]+), ([\d.]+)", text, re.S)
    return {
        "removed_vertices": num(r"Removed vertices: ([\d,]+)", int),
        "collapsed_rings": num(r"Collapsed rings: ([\d,]+)", int),
        "mean_displacement_m": num(r"Mean displacement: ([\d.]+)"),
        "max_displacement_m": num(r"Max displacement: ([\d.]+)"),
        "displacement_quartiles_m": [float(x) for x in q.groups()] if q else None,
        "repair_messages": re.findall(r"^.*(?:[Rr]epair|intersection|sliver|gap).*$", text, re.M),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--lod", required=True)
    ap.add_argument("--interval", type=float, required=True, help="simplification interval in metres")
    ap.add_argument("--out-root", help="override output root (for candidate experiments)")
    ap.add_argument("--precision", default=PRECISION, help="coordinate precision in degrees")
    ap.add_argument("--method", choices=["dp", "weighted"], default="dp",
                    help="dp = Douglas-Peucker (bounded displacement); weighted = weighted Visvalingam")
    args = ap.parse_args()

    raw = DATA_RAW / "SRC-0001" / args.snapshot
    pages = sorted(str(p) for p in raw.glob("kabkota_geom_*.geojson"))
    proc = REPO_ROOT / "data" / "processed" / "geography" / args.snapshot
    out = Path(args.out_root) / args.lod if args.out_root else proc / "render" / args.lod
    out.mkdir(parents=True, exist_ok=True)

    member = load_nav_groups()
    kab_csv, prov_csv = write_join_tables(proc / "render" / "_join", member)

    node = ["node", "--max-old-space-size=12288", str(MAPSHAPER)]
    stage = out / "_stage"
    stage.mkdir(exist_ok=True)
    copy_kab = "copy-fields=" + ",".join(f for f in KAB_FIELDS.split(",") if f != "region_id")
    # Pass A: merge, dissolve terapung parts, join, explode, simplify; write the simplified
    # parts. mapshaper simplification is non-destructive (vertices are dropped only on
    # output), so cleaning/dissolving in the same pass would see the ORIGINAL geometry.
    # Writing and re-importing "bakes" the simplification so pass B repairs what is shipped.
    pass_a = node + [
        "-i", *pages, "combine-files",
        "-merge-layers", "force", "name=src",
        "-each", "KDPKAB = String(KDPKAB).trim(); KDPPUM = String(KDPPUM).trim()",
        "-filter", "TIPADM == 6", "+", "name=fragments",
        "-each", "fragment_id = 'F' + OBJECTID; parent_region_id = KDPPUM; remark = String(REMARK || '').trim()",
        "target=fragments",
        "-filter-fields", "fragment_id,parent_region_id,remark", "target=fragments",
        "-filter", "TIPADM != 6", "target=src",
        "-dissolve", "KDPKAB", "name=kabkota", "target=src",
        "-join", str(kab_csv), "keys=KDPKAB,KDPKAB", f"string-fields=KDPKAB,{KAB_FIELDS}", "unmatched",
        "target=kabkota",
        "-filter-fields", KAB_FIELDS, "target=kabkota",
        "-explode", "target=kabkota,fragments",
        "-simplify", *(["dp"] if args.method == "dp" else []), f"interval={args.interval:g}m", "keep-shapes", "stats",
        "-o", str(stage) + "/", "format=geojson", f"precision={args.precision}", "target=kabkota,fragments",
    ]
    # Pass B: on the baked geometry, -clean resolves overlaps/self-crossings (e.g. a simplified
    # coastline cutting through a tiny kept islet; gap-width=0 never fills real gaps or bays),
    # re-dissolve parts per region, round inside mapshaper with fix-geometry, clean again,
    # then dissolve provinces from the final kab/kota layer (identical shared borders).
    pass_b = node + [
        "-i", str(stage / "kabkota.json"), str(stage / "fragments.json"), "combine-files",
        "string-fields=" + KAB_FIELDS + ",fragment_id",
        "-clean", "gap-width=0", "target=kabkota",
        "-clean", "gap-width=0", "target=fragments",
        "-dissolve", "region_id", copy_kab, "target=kabkota",
        "-dissolve", "fragment_id", "copy-fields=parent_region_id,remark", "target=fragments",
        "-snap", f"precision={args.precision}", "fix-geometry", "target=kabkota,fragments",
        "-clean", "gap-width=0", "target=kabkota",
        "-clean", "gap-width=0", "target=fragments",
        "-dissolve", "parent_region_id", "+", "name=provinsi", "target=kabkota",
        "-join", str(prov_csv), "keys=parent_region_id,parent_region_id",
        f"string-fields=parent_region_id,{PROV_FIELDS}", "target=provinsi",
        "-filter-fields", PROV_FIELDS, "target=provinsi",
        "-o", str(out) + "/", "format=geojson", f"precision={args.precision}",
        "target=kabkota,provinsi,fragments",
    ]
    print(f"[{args.lod}] mapshaper over {len(pages)} raw pages, interval={args.interval:g} m")
    started = utc_now_iso()
    run_a = subprocess.run(pass_a, capture_output=True, text=True)
    run_b = subprocess.run(pass_b, capture_output=True, text=True) if run_a.returncode == 0 else None
    log_a = run_a.stdout + run_a.stderr
    log_b = (run_b.stdout + run_b.stderr) if run_b else ""
    rc = run_a.returncode or (run_b.returncode if run_b else 1)
    if rc == 0:
        shutil.rmtree(stage)
    version = subprocess.run(["node", str(MAPSHAPER), "-v"], capture_output=True, text=True).stdout.strip()

    def rel(cmd):
        return [c if not c.startswith(str(REPO_ROOT)) else str(Path(c).relative_to(REPO_ROOT))
                for c in cmd if c not in pages]

    build_log = {
        "lod": args.lod, "snapshot_id": args.snapshot, "started_at": started, "finished_at": utc_now_iso(),
        "mapshaper_version": version, "interval_m": args.interval, "simplify_method": args.method, "precision_deg": float(args.precision),
        "method": f"pass A: {'Douglas-Peucker' if args.method == 'dp' else 'weighted Visvalingam'} (spherical), keep-shapes on exploded parts, intersection "
                  "repair on; pass B on baked geometry: clean gap-width=0, dissolve, in-pipeline rounding "
                  "with fix-geometry, clean, province dissolve",
        "raw_pages": len(pages), "returncode": rc,
        "command_pass_a": rel(pass_a) + [f"<{len(pages)} raw pages>"], "command_pass_b": rel(pass_b),
        "stats": parse_stats(log_a), "messages_pass_a": log_a.splitlines()[-60:],
        "messages_pass_b": log_b.splitlines()[-60:],
    }
    (out / "build_log.json").write_text(json.dumps(build_log, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(log_a[-2500:])
    print(log_b[-2500:])
    if rc != 0:
        print("mapshaper reported an error; see build_log.json")
    return rc


if __name__ == "__main__":
    sys.exit(main())
