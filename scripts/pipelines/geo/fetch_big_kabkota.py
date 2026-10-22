"""Fetch BIG 'Wilayah Administrasi Kabupaten/Kota' (edisi September 2023) raw captures.

Source: SRC-BIG-ADM-KABKOTA (see research/sources/SOURCE_REGISTRY.yaml)
Outputs (immutable raw):
  data/raw/big/kabkota_2023-09/service_metadata.json
  data/raw/big/kabkota_2023-09/attributes.json          (all attributes, no geometry)
  data/raw/big/kabkota_2023-09/features/<objectid>.geojson   (full-resolution, EPSG:4326; gitignored)
  data/raw/big/kabkota_2023-09/MANIFEST.json            (checksums; committed)

Usage: python3 scripts/pipelines/geo/fetch_big_kabkota.py [--refresh] [--attributes-only]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, fetch_to_file, log_access, sha256_file, utc_now  # noqa: E402

SOURCE_ID = "SRC-BIG-ADM-KABKOTA"
SERVICE = "https://geoservices.big.go.id/rbi/rest/services/Hosted/Wilayah_Administrasi_Kabupaten__Kota/FeatureServer/0"
OUT = REPO_ROOT / "data" / "raw" / "big" / "kabkota_2023-09"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--refresh", action="store_true")
    ap.add_argument("--attributes-only", action="store_true")
    args = ap.parse_args()

    meta = fetch_to_file(SERVICE, OUT / "service_metadata.json", SOURCE_ID, params={"f": "json"}, refresh=args.refresh)
    attrs = fetch_to_file(
        f"{SERVICE}/query", OUT / "attributes.json", SOURCE_ID, refresh=args.refresh,
        params={"where": "1=1", "outFields": "*", "returnGeometry": "false", "f": "json"},
    )
    data = json.loads(attrs.read_text(encoding="utf-8"))
    if data.get("exceededTransferLimit"):
        log_access(SOURCE_ID, SERVICE, "warning", "attribute query exceeded transfer limit; paging required")
        raise SystemExit("attribute query truncated; implement paging")
    oids = sorted(f["attributes"]["objectid"] for f in data["features"])
    print(f"{len(oids)} features listed")

    failed: list[int] = []
    if not args.attributes_only:
        for i, oid in enumerate(oids, 1):
            dest = OUT / "features" / f"{oid}.geojson"
            try:
                fetch_to_file(
                    f"{SERVICE}/query", dest, SOURCE_ID, refresh=args.refresh, delay_s=0.5,
                    params={"where": f"objectid={oid}", "outFields": "*", "returnGeometry": "true",
                            "outSR": "4326", "f": "geojson"},
                )
            except RuntimeError as e:
                print(e, file=sys.stderr)
                failed.append(oid)
            if i % 25 == 0:
                print(f"  {i}/{len(oids)}", flush=True)

    files = {p.relative_to(OUT).as_posix(): {"sha256": sha256_file(p), "bytes": p.stat().st_size}
             for p in sorted(OUT.rglob("*")) if p.is_file() and p.name != "MANIFEST.json" and not p.name.endswith(".part")}
    manifest = {
        "source_id": SOURCE_ID,
        "service_url": SERVICE,
        "edition": "September 2023 (metadata tag TASWIL5000020230907KABKOTA)",
        "retrieved_at": utc_now(),
        "feature_count_listed": len(oids),
        "failed_objectids": failed,
        "files": files,
    }
    (OUT / "MANIFEST.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    log_access(SOURCE_ID, SERVICE, "ok" if not failed else "partial", f"{len(files)} files, {len(failed)} failed")
    print(f"done: {len(files)} files, failed={failed}")
    return 0 if not failed else 2


if __name__ == "__main__":
    raise SystemExit(main())
