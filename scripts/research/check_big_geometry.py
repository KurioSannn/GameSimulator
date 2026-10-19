"""Verify that the raw BIG geometry capture (SRC-0001) is complete.

Compares OBJECTIDs in kabkota_attributes.json with those found in the
kabkota_geom_*.geojson pages, and reports missing, duplicated or empty
geometries. Writes research/reports/geometry_capture_check.json.

Exit code is non-zero if any registry region lacks geometry.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, sha256_bytes, utc_now_iso


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    args = ap.parse_args()
    raw = DATA_RAW / "SRC-0001" / args.snapshot

    attrs = {f["attributes"]["OBJECTID"]: f["attributes"]
             for f in json.loads((raw / "kabkota_attributes.json").read_text())["features"]}
    seen: Counter = Counter()
    empty, vertices = [], {}
    integrity = []
    recovered = []
    pages = sorted(raw.glob("kabkota_geom_*.geojson"))
    for page in pages:
        meta = json.loads(page.with_name(page.name + ".meta.json").read_text())
        data = page.read_bytes()
        feats = json.loads(data)["features"]
        if "_oid" in page.name:  # server-timeout recovery copy (maxAllowableOffset 1e-7 deg), one feature
            expected = 1
            recovered.append({"page": page.name, "OBJECTID": feats[0]["properties"]["OBJECTID"] if feats else None,
                              "url": meta["url"]})
        else:
            offset = int(page.name.split("_")[2].split(".")[0])
            expected = 1 if "_n1" in page.name else min(10, len(attrs) - offset)
        problems = []
        if sha256_bytes(data) != meta["sha256"]:
            problems.append("sha256 mismatch")
        if len(data) != meta["bytes"]:
            problems.append("size mismatch")
        if len(feats) != expected:
            problems.append(f"{len(feats)} features, expected {expected}")
        if problems:
            integrity.append({"page": page.name, "problems": problems})
        for feat in feats:
            oid = feat["properties"]["OBJECTID"]
            seen[oid] += 1
            geom = feat.get("geometry")
            if not geom or not geom.get("coordinates"):
                empty.append(oid)
                continue
            polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
            vertices[oid] = sum(len(ring) for poly in polys for ring in poly)

    missing = sorted(set(attrs) - set(seen))
    dupes = sorted(o for o, n in seen.items() if n > 1)
    registry = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text())
    regions_missing = sorted(
        r["region_id"] for r in registry["regions"]
        if any(int(o) in missing or int(o) in empty for o in r["big_objectids"].split(";"))
    )
    report = {
        "snapshot_id": args.snapshot,
        "checked_at": utc_now_iso(),
        "pages": len(pages),
        "page_bytes_total": sum(p.stat().st_size for p in pages),
        "page_integrity_problems": integrity,
        "recovered_features_not_full_resolution": recovered,
        "features_expected": len(attrs),
        "features_captured": len(seen),
        "missing_objectids": [{"OBJECTID": o, "name": attrs[o]["NAMOBJ"], "KDPKAB": attrs[o]["KDPKAB"]} for o in missing],
        "duplicate_objectids": dupes,
        "empty_geometry_objectids": empty,
        "registry_regions_affected": regions_missing,
        "total_vertices": sum(vertices.values()),
        "max_vertices_feature": max(vertices.items(), key=lambda kv: kv[1]) if vertices else None,
    }
    out = REPO_ROOT / "research" / "reports" / "geometry_capture_check.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "missing_objectids"}, indent=1))
    print(f"missing: {len(missing)}")
    return 1 if (regions_missing or missing or dupes or empty or integrity) else 0


if __name__ == "__main__":
    sys.exit(main())
