"""Audit the unit/semantics of BIG LUASWH and Shape_Area (GAP-0004).

Nothing here converts or overwrites a source value. For every kab/kota main
polygon in SRC-0001 the script records, side by side:

  luaswh_raw            BIG LUASWH as published; field alias
                        "Luas Wilayah Menurut Peraturan (HA)"
  shape_area_raw        BIG Shape_Area as published (layer CRS is EPSG:4326)
  planar_deg2           shoelace area of the raw coordinates in degree units,
                        to test whether Shape_Area is planar square degrees
  geom_area_km2         ellipsoidal equal-area area of the raw full-res
                        polygon (geo.area_km2), a DERIVED value
  bps_area_km2          BPS provincial table "Luas Wilayah" (km2) with its
                        table year and cited source decree (SRC-0008)

Outputs:
  data/processed/geography/<snap>/area_unit_audit.csv      (all regions)
  research/reports/area_unit_audit_summary.json            (stats + sample)
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, utc_now_iso
from geo import area_km2, polygons_of

LUASWH_LABEL = "Luas Wilayah Menurut Peraturan (HA)"

# Varied, pre-declared sample (small cities, large regencies, all seven navigation groups).
SAMPLE = [
    "12.73",  # Kota Sibolga            Sumatra    - smallest-class city
    "13.75",  # Kota Bukittinggi        Sumatra
    "61.06",  # Kab. Kapuas Hulu        Kalimantan - large regency
    "65.02",  # Kab. Malinau            Kalimantan - large regency
    "31.01",  # Kab. Adm. Kep. Seribu   Jawa       - tiny islands only
    "33.71",  # Kota Magelang           Jawa       - small city
    "35.76",  # Kota Mojokerto          Jawa       - small city
    "35.78",  # Kota Surabaya           Jawa
    "32.01",  # Kab. Bogor              Jawa
    "51.08",  # Kab. Buleleng           Bali-NT
    "53.11",  # Kab. Sumba Timur        Bali-NT
    "73.71",  # Kota Makassar           Sulawesi
    "74.07",  # Kab. Wakatobi           Sulawesi   - has 'Wilayah terapung'
    "82.02",  # Kab. Halmahera Tengah   Maluku
    "81.01",  # Kab. Maluku Tengah      Maluku
    "93.01",  # Kab. Merauke            Papua      - largest-class regency
    "94.04",  # Kab. Mimika             Papua
]


def planar_deg2(geom: dict) -> float:
    def ring(r):
        return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(r, r[1:]))) / 2
    return sum(ring(p[0]) - sum(ring(h) for h in p[1:]) for p in polygons_of(geom))


def load_bps_areas(proc_dir: Path) -> dict:
    """kode_bps -> best BPS area record (prefer the 2025 table over 2024)."""
    out = {}
    for f in sorted(proc_dir.glob("bps_area_tables_*.json"), reverse=True):  # 2025 files sort first
        for t in json.loads(f.read_text(encoding="utf-8"))["tables"]:
            if t.get("status") != "ok":
                continue
            for r in t["rows"]:
                code = r["kode_wilayah_bps"][:4]
                if len(r["kode_wilayah_bps"]) != 7 or code.endswith("00") or r["area_value"] is None:
                    continue  # province total rows / non-numeric
                rec = {"bps_area_km2": r["area_value"], "bps_area_raw": r["area_value_raw"],
                       "bps_unit": t["area_unit"], "bps_table_year": t["tahun_data"],
                       "bps_sumber": t["sumber"], "bps_url": t["url"], "bps_label": r["label"]}
                if code not in out or out[code]["bps_table_year"] < t["tahun_data"]:
                    out[code] = rec
    return out


def ratio(a, b):
    return a / b if a not in (None, "") and b not in (None, "", 0) else None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    args = ap.parse_args()
    raw = DATA_RAW / "SRC-0001" / args.snapshot
    proc = REPO_ROOT / "data" / "processed" / "geography" / args.snapshot
    registry = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))

    geoms = {}
    for page in sorted(raw.glob("kabkota_geom_*.geojson")):
        for f in json.loads(page.read_text(encoding="utf-8"))["features"]:
            p = f["properties"]
            geoms[p["OBJECTID"]] = {"geom": f["geometry"], "Shape_Area": p.get("Shape_Area"),
                                    "LUASWH": p.get("LUASWH")}
    bps = load_bps_areas(proc)

    rows = []
    for r in registry["regions"]:
        oids = [int(x) for x in r["big_objectids"].split(";")]
        floating = {int(x) for x in r["big_floating_area_objectids"].split(";") if x}
        main = [o for o in oids if o not in floating][0]
        g = geoms.get(main)
        b = bps.get(r["kode_bps"], {})
        row = {
            "region_id": r["region_id"], "kode_bps": r["kode_bps"], "name": r["name"],
            "region_level": r["region_level"], "big_objectid": main,
            "luaswh_raw": r["big_luaswh_raw"], "luaswh_source_label": LUASWH_LABEL, "luaswh_declared_unit": "HA",
            # evidenced interpretation kept separate from the declared metadata (D-017)
            "luaswh_evidenced_unit": "km2", "luaswh_unit_status": "UNIT_KM2_EVIDENCED",
            "luaswh_unit_evidence": "research/reports/AREA_UNIT_INVESTIGATION.md",
            "shape_area_raw": g["Shape_Area"] if g else "",
            "planar_deg2": planar_deg2(g["geom"]) if g else "",
            "geom_area_km2": area_km2(g["geom"]) if g else "",
            "geom_area_method": "WGS84 ellipsoidal cylindrical equal-area (authalic), raw full-res main polygon" if g else "",
            "bps_area_km2": b.get("bps_area_km2", ""), "bps_area_raw": b.get("bps_area_raw", ""),
            "bps_unit": b.get("bps_unit", ""), "bps_table_year": b.get("bps_table_year", ""),
            "bps_sumber": b.get("bps_sumber", ""), "bps_url": b.get("bps_url", ""),
            "geometry_captured": bool(g),
        }
        lw = float(row["luaswh_raw"]) if row["luaswh_raw"] != "" else None
        row["ratio_luaswh_to_geom_km2"] = ratio(lw, row["geom_area_km2"] or None)
        row["ratio_luaswh_to_bps_km2"] = ratio(lw, row["bps_area_km2"] or None)
        row["ratio_geom_km2_to_bps_km2"] = ratio(row["geom_area_km2"] or None, row["bps_area_km2"] or None)
        row["ratio_shape_area_to_planar_deg2"] = ratio(row["shape_area_raw"] or None, row["planar_deg2"] or None)
        # A BPS figure ~1000x the BIG km2 value is flagged, never "fixed": Sulawesi Tenggara's
        # 2025 table publishes e.g. Kolaka as "2.958.870,00 km2" (BIG: 2,958.87 km2).
        rl = row["ratio_luaswh_to_bps_km2"]
        row["bps_value_flag"] = ("THOUSANDFOLD_SUSPECTED" if rl is not None and abs(rl * 1000 - 1) <= 0.01
                                 else ("" if rl is None else "OK"))
        rows.append(row)

    proc.mkdir(parents=True, exist_ok=True)
    with (proc / "area_unit_audit.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    def stats(key, subset=None):
        vals = [r[key] for r in (subset or rows) if r[key] is not None]
        if not vals:
            return {"n": 0}
        q = statistics.quantiles(vals, n=20) if len(vals) >= 20 else None
        return {"n": len(vals), "median": statistics.median(vals), "min": min(vals), "max": max(vals),
                "p05": q[0] if q else None, "p95": q[-1] if q else None,
                "within_1pct": sum(abs(v - 1) <= 0.01 for v in vals),
                "within_5pct": sum(abs(v - 1) <= 0.05 for v in vals),
                "near_100x": sum(abs(v / 100 - 1) <= 0.05 for v in vals)}

    for r in rows:
        if r["bps_value_flag"] == "THOUSANDFOLD_SUSPECTED":
            r["ratio_luaswh_to_bps_km2"] = r["ratio_geom_km2_to_bps_km2"] = None  # excluded from stats
    same_decree = [r for r in rows if "2138" in str(r["bps_sumber"])]
    summary = {
        "snapshot_id": args.snapshot, "built_at": utc_now_iso(),
        "regions": len(rows), "with_geometry": sum(r["geometry_captured"] for r in rows),
        "with_bps_area": sum(r["bps_area_km2"] != "" for r in rows),
        "with_bps_area_citing_2138_2025": len(same_decree),
        "bps_thousandfold_suspected": sum(r["bps_value_flag"] == "THOUSANDFOLD_SUSPECTED" for r in rows),
        "ratio_luaswh_to_geom_km2": stats("ratio_luaswh_to_geom_km2"),
        "ratio_luaswh_to_bps_km2_all": stats("ratio_luaswh_to_bps_km2"),
        "ratio_luaswh_to_bps_km2_same_decree": stats("ratio_luaswh_to_bps_km2", same_decree),
        "ratio_geom_km2_to_bps_km2": stats("ratio_geom_km2_to_bps_km2"),
        "ratio_shape_area_to_planar_deg2": stats("ratio_shape_area_to_planar_deg2"),
        "exact_match_luaswh_bps_2dp": sum(1 for r in rows if r["bps_area_km2"] != "" and r["bps_value_flag"] == "OK" and
                                          round(float(r["luaswh_raw"]), 2) == round(r["bps_area_km2"], 2)),
        "sample": [{k: r[k] for k in ("region_id", "name", "luaswh_raw", "shape_area_raw", "geom_area_km2",
                                       "bps_area_km2", "bps_table_year", "bps_sumber",
                                       "ratio_luaswh_to_geom_km2", "ratio_luaswh_to_bps_km2",
                                       "ratio_geom_km2_to_bps_km2")}
                   for r in rows if r["region_id"] in SAMPLE],
    }
    out = REPO_ROOT / "research" / "reports" / "area_unit_audit_summary.json"
    out.write_text(json.dumps(summary, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k != "sample"}, indent=1))


if __name__ == "__main__":
    main()
