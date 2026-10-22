"""Build the canonical region registry (38 provinsi + 514 kabupaten/kota) and a crosswalk report.

Inputs (raw, immutable):
  data/raw/big/kabkota_2023-09/attributes.json                       PRIMARY  (SRC-BIG-ADM-KABKOTA)
  data/raw/kemendagri_secondary/cahyadsn_wilayah_2025/extracted_level_1_2.csv  SECONDARY cross-check
      (SRC-KEMENDAGRI-KODE-2025-SECONDARY)

Outputs:
  data/normalized/regions/region_registry.json
  research/reports/validation/geo_region_crosswalk.md

Primary key: Kemendagri administrative code ("PP" for provinsi, "PP.KK" for kab/kota), which BIG
publishes in field `kdpkab`. Names are display labels only.
"""
from __future__ import annotations

import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

RAW_BIG = REPO_ROOT / "data/raw/big/kabkota_2023-09/attributes.json"
RAW_SEC = REPO_ROOT / "data/raw/kemendagri_secondary/cahyadsn_wilayah_2025/extracted_level_1_2.csv"
# BPS <-> Kemendagri crosswalk validated in geography v2 (SRC-0002, BPS bridging period 2025_2.2025, D-050).
CROSSWALK = REPO_ROOT / "data/normalized/geography/crosswalk_bps_kemendagri.csv"
OUT = REPO_ROOT / "data/normalized/regions/region_registry.json"
REPORT = REPO_ROOT / "research/reports/validation/geo_region_crosswalk.md"

# Navigation/visual grouping ONLY (docs/08: must not overwrite official hierarchy). Keyed by province code.
ISLAND_GROUP = {
    **{c: "sumatera" for c in ("11", "12", "13", "14", "15", "16", "17", "18", "19", "21")},
    **{c: "jawa" for c in ("31", "32", "33", "34", "35", "36")},
    "51": "bali_nusa_tenggara", "52": "bali_nusa_tenggara", "53": "bali_nusa_tenggara",
    **{c: "kalimantan" for c in ("61", "62", "63", "64", "65")},
    **{c: "sulawesi" for c in ("71", "72", "73", "74", "75", "76")},
    "81": "maluku", "82": "maluku",
    **{c: "papua" for c in ("91", "92", "93", "94", "95", "96")},
}
TIPADM = {4: "kabupaten", 5: "kota"}
CODE_RE = re.compile(r"^\d\d\.\d\d$")
# Display-name policy: BIG (primary official) `namobj` wins. Overrides only where BIG uses an abbreviation;
# each override must cite the source of the full form.
NAME_OVERRIDES = {
    "31.01": ("Kepulauan Seribu", "BIG namobj is abbreviated 'Adm. Kep. Seribu'; full form per Kepmendagri 2025 list (secondary)"),
}


def norm_name(s: str) -> str:
    s = s.lower().replace("kabupaten ", "").replace("kota ", "").replace("adm. ", "").replace("administrasi ", "")
    return re.sub(r"[^a-z0-9]", "", s)


def main() -> int:
    big = json.loads(RAW_BIG.read_text(encoding="utf-8"))
    rows = [f["attributes"] for f in big["features"]]
    sec = {r["kode"]: r for r in csv.DictReader(RAW_SEC.open(encoding="utf-8"))}
    kode_bps = {r["kode_kemendagri"]: r["kode_bps"] for r in csv.DictReader(CROSSWALK.open(encoding="utf-8"))}

    by_code: dict[str, list[dict]] = defaultdict(list)
    excluded = []
    for r in rows:
        code = (r.get("kdpkab") or "").strip()
        if CODE_RE.match(code):
            by_code[code].append(r)
        else:
            excluded.append(r)

    issues: list[str] = []
    regions = []
    for code in sorted(by_code):
        parts = by_code[code]
        first = parts[0]
        names = {p["namobj"] for p in parts}
        if len(names) > 1:
            issues.append(f"{code}: multiple BIG names {sorted(names)}")
        kind = TIPADM.get(first["tipadm"])
        if kind is None:
            issues.append(f"{code}: unexpected tipadm {first['tipadm']}")
        s = sec.get(code)
        sec_name = s["nama"] if s else None
        if s is None:
            issues.append(f"{code} ({first['namobj']}): missing from secondary Kepmendagri list")
        else:
            sec_kind = "kota" if sec_name.lower().startswith("kota") else "kabupaten"
            if sec_kind != kind:
                issues.append(f"{code}: type mismatch BIG={kind} secondary={sec_kind} ({sec_name})")
            if norm_name(sec_name) != norm_name(first["namobj"]):
                issues.append(f"{code}: name differs BIG='{first['namobj']}' secondary='{sec_name}'")
        prov = code[:2]
        if code not in kode_bps:
            issues.append(f"{code}: missing from BPS<->Kemendagri crosswalk")
        regions.append({
            "region_id": code,
            "kode_bps": kode_bps.get(code),
            "level": "kabkota",
            "kind": kind,
            "parent_region_id": prov,
            "name": NAME_OVERRIDES.get(code, (first["namobj"],))[0],
            "name_kemendagri_secondary": sec_name,
            "name_big": first["namobj"],
            "ibukota": (s or {}).get("ibukota") or None,
            "island_group": ISLAND_GROUP.get(prov),
            "area_km2_big": round(sum(p["luaswh"] or 0 for p in parts), 6),
            "big_objectids": sorted(p["objectid"] for p in parts),
            "provenance": {
                "code": "SRC-BIG-ADM-KABKOTA:kdpkab; cross-checked SRC-KEMENDAGRI-KODE-2025-SECONDARY",
                "kode_bps": "SRC-0002 (BPS bridging 2025_2.2025) via data/normalized/geography/crosswalk_bps_kemendagri.csv",
                "name": NAME_OVERRIDES[code][1] if code in NAME_OVERRIDES else "SRC-BIG-ADM-KABKOTA:namobj",
                "area_km2_big": "SRC-BIG-ADM-KABKOTA:luaswh (sum over parts; unit km2 per BIG field definition — VERIFY)",
            },
        })

    prov_codes = sorted({r["parent_region_id"] for r in regions})
    provinces = []
    for pc in prov_codes:
        s = sec.get(pc)
        big_names = {r["wadmpr"] for r in rows if (r.get("kdpkab") or "").startswith(pc + ".")}
        if s is None:
            issues.append(f"province {pc}: missing from secondary list")
        if pc not in kode_bps:
            issues.append(f"province {pc}: missing from BPS<->Kemendagri crosswalk")
        provinces.append({
            "region_id": pc, "kode_bps": kode_bps.get(pc), "level": "provinsi", "kind": "provinsi", "parent_region_id": "ID",
            "name": s["nama"] if s else sorted(big_names)[0],
            "name_big": sorted(big_names)[0] if big_names else None,
            "ibukota": (s or {}).get("ibukota") or None,
            "island_group": ISLAND_GROUP.get(pc),
            "area_km2_big": round(sum(r["area_km2_big"] for r in regions if r["parent_region_id"] == pc), 6),
            "provenance": {"name": "SRC-KEMENDAGRI-KODE-2025-SECONDARY:nama", "area_km2_big": "DERIVED: sum of child kab/kota",
                           "kode_bps": "SRC-0002 (BPS bridging 2025_2.2025) via data/normalized/geography/crosswalk_bps_kemendagri.csv"},
        })
    sec_kk = {k for k in sec if CODE_RE.match(k)}
    for k in sorted(sec_kk - set(by_code)):
        issues.append(f"{k} ({sec[k]['nama']}): in secondary list but has no BIG geometry")

    counts = {"provinsi": len(provinces), "kabupaten": sum(r["kind"] == "kabupaten" for r in regions),
              "kota": sum(r["kind"] == "kota" for r in regions)}
    out = {
        "schema": "nusantara.region_registry/1",
        "generated_at": utc_now(),
        "generator": "scripts/pipelines/geo/build_region_registry.py",
        "admin_baseline": "Kepmendagri 300.2.2-2138 Tahun 2025 (via secondary transcription; official PDF pending)",
        "geometry_baseline": "BIG batas wilayah administrasi kab/kota edisi September 2023",
        "counts": counts,
        "excluded_big_features": [
            {"objectid": r["objectid"], "namobj": r["namobj"], "kdpkab": r.get("kdpkab"), "tipadm": r["tipadm"],
             "remark": r.get("remark")} for r in excluded],
        "provinces": provinces,
        "kabkota": regions,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding="utf-8")

    REPORT.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Geo region crosswalk validation", "", f"Generated: {out['generated_at']}", "",
        f"- Provinsi: **{counts['provinsi']}** (expected 38 per Kepmendagri 2025)",
        f"- Kabupaten: **{counts['kabupaten']}** (expected 416)",
        f"- Kota: **{counts['kota']}** (expected 98)",
        f"- BIG features excluded (no valid single kab/kota code; disputed/uncoded areas): **{len(excluded)}**",
        f"- Kab/kota represented by multiple BIG polygons rows: "
        f"{sorted(c for c, p in by_code.items() if len(p) > 1)}", "",
        "## Issues", "",
        *(f"- {i}" for i in issues), *(["- none"] if not issues else []), "",
        "## Excluded BIG features", "",
        "| objectid | namobj | kdpkab | tipadm | remark |", "|---|---|---|---|---|",
        *(f"| {r['objectid']} | {r['namobj']} | {r.get('kdpkab')!s} | {r['tipadm']} | {r.get('remark')!s} |" for r in excluded),
        "", "Excluded areas are kept in raw data and are rendered as neutral, non-selectable map areas "
        "(disputed/unassigned); they are never assigned to a region by this pipeline.",
    ]
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(counts), f"issues={len(issues)}", f"excluded={len(excluded)}")
    ok = counts == {"provinsi": 38, "kabupaten": 416, "kota": 98}
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
