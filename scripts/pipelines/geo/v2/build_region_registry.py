"""Build the normalized region registry from raw captures.

Inputs (immutable raw, see data/catalog/):
  SRC-0002  BPS <-> Kemendagri bridging, period 2025_2.2025
  SRC-0001  BIG BATAS_KABKOTA_AR attributes, edisi Juni 2026

Key strategy (DECISIONS.md D-050):
  region_id = Kemendagri code ("11", "11.05"), the legal administrative code.
  BPS codes are carried as a crosswalk column, never used as the primary key.

Outputs (data/normalized/geography/):
  provinces.csv, regions_kabkota.csv, crosswalk_bps_kemendagri.csv,
  big_unallocated_fragments.csv, region_registry.json
  and research/reports/geography_validation.json

Exit code is non-zero if any hard validation check fails.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, sha256_file, utc_now_iso

PERIOD = "2025_2.2025"
EXPECTED = {"provinsi": 38, "kabupaten": 416, "kota": 98}
BIG_TIPADM = {4: "kabupaten", 5: "kota", 6: "unallocated_fragment"}


def norm_name(s: str) -> str:
    s = s.upper()
    s = re.sub(r"^(KABUPATEN|KAB\.?|KOTA)\s+", "", s)
    s = re.sub(r"^(ADMINISTRASI|ADM\.)\s+", "", s)
    return re.sub(r"[^A-Z0-9]", "", s)


def normalize_dagri_kab_code(raw: str) -> str:
    """SIG BPS serves some Kemendagri codes with the trailing zero dropped
    ("11.1" for "11.10", float-style rendering), while leading zeros survive
    ("11.01"). Kemendagri kab/kota codes are always PP.KK, so right-pad KK.
    Verified independently against BIG KDPKAB (build check below)."""
    prov, kab = raw.split(".")
    return f"{prov}.{kab.ljust(2, '0')}"


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    args = ap.parse_args()
    bps_dir = DATA_RAW / "SRC-0002" / args.snapshot
    big_dir = DATA_RAW / "SRC-0001" / args.snapshot

    inputs = [bps_dir / f"bridging_provinsi_{PERIOD}.json", big_dir / "kabkota_attributes.json"]
    prov_raw = load_json(inputs[0])
    kab_raw = []
    for p in prov_raw:
        f = bps_dir / f"bridging_kabupaten_{PERIOD}_{p['kode_bps']}.json"
        inputs.append(f)
        kab_raw += [dict(r, _prov_bps=p["kode_bps"], _prov_dagri=p["kode_dagri"]) for r in load_json(f)]
    big = [f["attributes"] for f in load_json(big_dir / "kabkota_attributes.json")["features"]]

    checks: list[dict] = []

    def check(name: str, ok: bool, detail="", hard=True):
        checks.append({"check": name, "passed": bool(ok), "hard": hard, "detail": detail})

    # ---- provinces --------------------------------------------------------
    provinces = []
    for p in prov_raw:
        provinces.append({
            "region_id": p["kode_dagri"],
            "region_level": "provinsi",
            "name": p["nama_dagri"],
            "name_bps": p["nama_bps"],
            "kode_kemendagri": p["kode_dagri"],
            "kode_bps": p["kode_bps"],
            "parent_region_id": "ID",
        })
    prov_ids = {p["region_id"] for p in provinces}

    # ---- kabupaten/kota ---------------------------------------------------
    big_by_code = defaultdict(list)
    fragments = []
    for b in big:
        kind = BIG_TIPADM.get(b["TIPADM"], f"unknown_{b['TIPADM']}")
        if kind == "unallocated_fragment":
            fragments.append({
                "big_objectid": b["OBJECTID"], "province_name": b["WADMPR"].strip(),
                "province_code_kemendagri": b["KDPPUM"].strip(), "luaswh_raw": b["LUASWH"],
                "remark": (b["REMARK"] or "").strip(), "metadata": b["METADATA"],
            })
        else:
            big_by_code[b["KDPKAB"].strip()].append(b)

    regions = []
    for r in kab_raw:
        code = normalize_dagri_kab_code(r["kode_dagri"])
        level = "kota" if r["nama_dagri"].upper().startswith("KOTA") else "kabupaten"
        polys = big_by_code.get(code, [])
        main_polys = [b for b in polys if (b["REMARK"] or "").strip() != "Wilayah terapung"]
        floating = [b for b in polys if (b["REMARK"] or "").strip() == "Wilayah terapung"]
        primary = main_polys[0] if main_polys else None
        regions.append({
            "region_id": code,
            "region_level": level,
            "name": r["nama_dagri"],
            "name_bps": r["nama_bps"],
            "kode_kemendagri": code,
            "kode_kemendagri_raw": r["kode_dagri"],
            "kode_bps": r["kode_bps"],
            "parent_region_id": r["_prov_dagri"],
            "province_kode_bps": r["_prov_bps"],
            "big_name": primary["WADMKK"] if primary else "",
            "big_tipadm_level": BIG_TIPADM.get(primary["TIPADM"], "") if primary else "",
            "big_objectids": ";".join(str(b["OBJECTID"]) for b in polys),
            "big_floating_area_objectids": ";".join(str(b["OBJECTID"]) for b in floating),
            "big_luaswh_raw": primary["LUASWH"] if primary else "",
            "big_metadata_edition": primary["METADATA"] if primary else "",
            "big_remark": (primary["REMARK"] or "").strip() if primary else "",
            "island_group": "",  # game navigation layer; not yet decided (see gap registry)
            "fact_class": "REAL_OFFICIAL",
        })

    # ---- validation -------------------------------------------------------
    by_level = defaultdict(int)
    for r in regions:
        by_level[r["region_level"]] += 1
    check("province_count == 38", len(provinces) == EXPECTED["provinsi"], len(provinces))
    check("kabupaten_count == 416", by_level["kabupaten"] == EXPECTED["kabupaten"], by_level["kabupaten"])
    check("kota_count == 98", by_level["kota"] == EXPECTED["kota"], by_level["kota"])
    ids = [r["region_id"] for r in regions]
    check("region_id unique", len(ids) == len(set(ids)), len(ids) - len(set(ids)))
    bps = [r["kode_bps"] for r in regions]
    check("kode_bps unique", len(bps) == len(set(bps)), len(bps) - len(set(bps)))
    bad_parent = [r["region_id"] for r in regions if r["parent_region_id"] not in prov_ids]
    check("every kab/kota has a known province", not bad_parent, bad_parent)
    bad_prefix = [r["region_id"] for r in regions if r["region_id"].split(".")[0] != r["parent_region_id"]]
    check("kemendagri code prefix == parent province", not bad_prefix, bad_prefix)
    bad_bps_prefix = [r["region_id"] for r in regions if r["kode_bps"][:2] != r["province_kode_bps"]]
    check("bps code prefix == bps province code", not bad_bps_prefix, bad_bps_prefix)
    no_geom = [r["region_id"] for r in regions if not r["big_objectids"]]
    check("every kab/kota has a BIG polygon", not no_geom, no_geom)
    registry_ids = set(ids)
    orphan = sorted(c for c in big_by_code if c not in registry_ids)
    check("every BIG kab/kota polygon maps to a registry region", not orphan, orphan)
    level_mismatch = [r["region_id"] for r in regions if r["big_tipadm_level"] and r["big_tipadm_level"] != r["region_level"]]
    check("BIG TIPADM level agrees with Kemendagri kab/kota", not level_mismatch, level_mismatch)
    big_prov_mismatch = sorted({b["KDPKAB"] for c, bs in big_by_code.items() for b in bs
                                if b["KDPPUM"].strip() != c.split(".")[0]})
    check("BIG KDPPUM agrees with KDPKAB prefix", not big_prov_mismatch, big_prov_mismatch)
    multi = {r["region_id"]: r["big_objectids"] for r in regions
             if len(r["big_objectids"].split(";")) - len([x for x in r["big_floating_area_objectids"].split(";") if x]) > 1}
    check("at most one main BIG polygon per region", not multi, multi)
    name_diff = [{"region_id": r["region_id"], "kemendagri": r["name"], "bps": r["name_bps"], "big": r["big_name"]}
                 for r in regions if len({norm_name(r["name"]), norm_name(r["name_bps"]), norm_name(r["big_name"])}) > 1]
    check("names agree across Kemendagri/BPS/BIG (normalized)", not name_diff, name_diff, hard=False)
    prov_code_diff = [{"kemendagri": p["kode_kemendagri"], "bps": p["kode_bps"], "name": p["name"]}
                      for p in provinces if p["kode_kemendagri"] != p["kode_bps"]]
    check("province codes identical in BPS and Kemendagri", not prov_code_diff, prov_code_diff, hard=False)

    # ---- write ------------------------------------------------------------
    out = DATA_NORMALIZED / "geography"
    out.mkdir(parents=True, exist_ok=True)

    def write_csv(name, rows, fields=None):
        fields = fields or list(rows[0].keys())
        with (out / name).open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=fields)
            w.writeheader()
            w.writerows(rows)

    provinces.sort(key=lambda p: p["region_id"])
    regions.sort(key=lambda r: r["region_id"])
    write_csv("provinces.csv", provinces)
    write_csv("regions_kabkota.csv", regions)
    write_csv("crosswalk_bps_kemendagri.csv",
              [{"region_level": x["region_level"], "kode_kemendagri": x["kode_kemendagri"],
                "kode_bps": x["kode_bps"], "name_kemendagri": x["name"], "name_bps": x["name_bps"]}
               for x in provinces + regions])
    write_csv("big_unallocated_fragments.csv", fragments)

    input_meta = [{"path": str(p.relative_to(REPO_ROOT)), "sha256": sha256_file(p)} for p in inputs]
    registry = {
        "snapshot_id": args.snapshot,
        "built_at": utc_now_iso(),
        "builder": "scripts/pipelines/geo/v2/build_region_registry.py",
        "key_strategy": "region_id = Kemendagri code; BPS code is a crosswalk attribute",
        "sources": {"SRC-0002": f"BPS SIG bridging, period {PERIOD}",
                    "SRC-0001": "BIG BATAS_KABKOTA_AR, edisi Juni 2026"},
        "inputs": input_meta,
        "counts": {"provinsi": len(provinces), **by_level, "kabupaten_kota": len(regions),
                   "big_unallocated_fragments": len(fragments)},
        "provinces": provinces,
        "regions": regions,
    }
    (out / "region_registry.json").write_text(json.dumps(registry, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")

    report = {"snapshot_id": args.snapshot, "built_at": registry["built_at"], "counts": registry["counts"], "checks": checks}
    rp = REPO_ROOT / "research" / "reports" / "geography_validation.json"
    rp.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    hard_fail = [c for c in checks if c["hard"] and not c["passed"]]
    for c in checks:
        flag = "PASS" if c["passed"] else ("FAIL" if c["hard"] else "WARN")
        detail = c["detail"] if not isinstance(c["detail"], (list, dict)) else f"{len(c['detail'])} item(s)"
        print(f"[{flag}] {c['check']}: {detail}")
    print(registry["counts"])
    return 1 if hard_fail else 0


if __name__ == "__main__":
    sys.exit(main())
