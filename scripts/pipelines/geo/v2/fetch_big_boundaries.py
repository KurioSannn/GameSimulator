"""Capture BIG administrative boundaries (SRC-0001, SRC-0005).

Source: Badan Informasi Geospasial, geoservices ArcGIS REST
  SRC-0001 BATASWILAYAH/BATAS_KABKOTA_AR/MapServer/0
           "Geodatabase data batas wilayah administrasi nasional edisi Juni 2026"
  SRC-0005 BATASWILAYAH/BATAS_WILAYAH/MapServer/12 (Area Batas Wilayah Administrasi Provinsi)

Raw pages are stored exactly as served (GeoJSON, full resolution, EPSG:4326).
No simplification happens here; render geometry is derived separately.

Usage:
  python3 scripts/pipelines/geo/v2/fetch_big_boundaries.py [--no-geometry]
"""

from __future__ import annotations

import argparse
import json
import urllib.parse

from common import arcgis_validate, fetch_raw

ROOT = "https://geoservices.big.go.id/rbi/rest/services/BATASWILAYAH"
LAYERS = {
    "SRC-0001": ("kabkota", f"{ROOT}/BATAS_KABKOTA_AR/MapServer/0", "OBJECTID"),
    "SRC-0005": ("provinsi", f"{ROOT}/BATAS_WILAYAH/MapServer/12", "objectid"),
    # Province boundary *lines* (edisi <= 2024-09): an independent cross-check for the
    # province outlines dissolved from SRC-0001, not a geometry source.
    "SRC-0007": ("provinsi_lines", f"{ROOT}/BATAS_WILAYAH/MapServer/8", "objectid"),
}
PAGE_SIZE = 10  # full-res polygons are ~0.2-5 MB each; keep responses modest


def query_url(layer: str, oid_field: str, **params) -> str:
    q = {"where": "1=1", "f": "json", **params}
    if "orderByFields" not in q and "returnCountOnly" not in q:
        q["orderByFields"] = oid_field
    return f"{layer}/query?" + urllib.parse.urlencode(q)


def capture(source_id: str, snapshot: str, with_geometry: bool) -> None:
    label, layer, oid = LAYERS[source_id]
    fetch_raw(source_id, snapshot, f"{label}_service.json", f"{layer}?f=pjson", validate=arcgis_validate)
    count_path = fetch_raw(source_id, snapshot, f"{label}_count.json",
                           query_url(layer, oid, returnCountOnly="true"), validate=arcgis_validate)
    count = json.loads(count_path.read_text())["count"]
    print(f"{source_id} {label}: {count} features")

    # Attribute-only queries are paged too: SRC-0007 has more rows (1,334) than maxRecordCount (1,000).
    for offset in range(0, count, 1000):
        fetch_raw(source_id, snapshot, f"{label}_attributes.json" if offset == 0 else f"{label}_attributes_{offset:05d}.json",
                  query_url(layer, oid, outFields="*", returnGeometry="false", resultOffset=offset,
                            resultRecordCount=1000), validate=arcgis_validate)

    if not with_geometry:
        return
    failed = []

    def page(offset: int, size: int) -> None:
        fetch_raw(source_id, snapshot, f"{label}_geom_{offset:05d}" + ("" if size == PAGE_SIZE else f"_n{size}") + ".geojson",
                  query_url(layer, oid, outFields="*", returnGeometry="true", f="geojson",
                            resultOffset=offset, resultRecordCount=size),
                  timeout=300, validate=arcgis_validate)

    for offset in range(0, count, PAGE_SIZE):
        try:
            page(offset, PAGE_SIZE)
        except RuntimeError as e:
            # Large pages can time out server-side (HTTP 500); retry feature by feature.
            print(f"  page {offset} failed ({e}); splitting")
            for single in range(offset, min(offset + PAGE_SIZE, count)):
                try:
                    page(single, 1)
                except RuntimeError as e1:
                    failed.append(single)
                    print(f"    feature at offset {single} failed: {e1}")
        print(f"  page {offset}/{count}")
    if failed:
        print(f"FAILED offsets (logged in source_access_log.csv): {failed}")


RECOVERY_OFFSET_DEG = "0.0000001"


def recover(source_id: str, snapshot: str, oid: int) -> None:
    """Fallback for a feature the server cannot serialize at full resolution.

    BIG returns HTTP 500 (after ~70-80 s) for OBJECTID 3424 (Kab. Sumbawa) at full
    resolution, with f=json, f=pbf, and with maxAllowableOffset <= 1e-8 deg.
    maxAllowableOffset=1e-7 deg succeeds; it bounds deviation from the full-resolution
    polygon to 1e-7 deg (~1.1 cm), far below the 1:50.000 source accuracy. The file is
    named so it can never be mistaken for an untouched full-resolution page.
    """
    label, layer, oid_field = LAYERS[source_id]
    fetch_raw(source_id, snapshot, f"{label}_geom_oid{oid:05d}_mao1e-7.geojson",
              f"{layer}/query?" + urllib.parse.urlencode({
                  "where": f"{oid_field}={oid}", "outFields": "*", "returnGeometry": "true",
                  "maxAllowableOffset": RECOVERY_OFFSET_DEG, "f": "geojson"}),
              timeout=400, validate=arcgis_validate)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--recover-oid", type=int, action="append",
                    help="fetch one OBJECTID with maxAllowableOffset=1e-7 deg (server-timeout fallback)")
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--no-geometry", action="store_true")
    ap.add_argument("--source", choices=sorted(LAYERS), action="append")
    args = ap.parse_args()
    if args.recover_oid:
        for oid in args.recover_oid:
            recover("SRC-0001", args.snapshot, oid)
        return
    for sid in args.source or ["SRC-0001", "SRC-0005"]:
        capture(sid, args.snapshot, not args.no_geometry)


if __name__ == "__main__":
    main()
