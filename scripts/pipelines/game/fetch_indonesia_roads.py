"""Fetch official Indonesian National Road (Jalan Nasional) and Operational Toll Road (Jalan Tol)
vector geometries directly from Kementerian Pekerjaan Umum (SIGI-PU) public ArcGIS REST services.

Sources:
  1. SRC-PUPR-JALAN-NASIONAL
     https://sigi.pu.go.id/serverpu/rest/services/Hosted/ast_bm_jalan_nasional_iri/FeatureServer/0
  2. SRC-PUPR-BPJT-TOL-OPERASI
     https://sigi.pu.go.id/serverpu/rest/services/Hosted/ast_bpjt_tol_operasi_v2/FeatureServer/0

Raw payloads are archived unmodified in data/raw/pupr_roads/ with SHA-256 checksums and provenance
metadata. Simplification and map projection happen only in build_indonesia_roads.py.

Usage: python scripts/pipelines/game/fetch_indonesia_roads.py [--refresh]
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib.fetch import REPO_ROOT, USER_AGENT, log_access, sha256_file, utc_now  # noqa: E402

RAW_DIR = REPO_ROOT / "data/raw/pupr_roads"

SERVICES = [
    {
        "source_id": "SRC-PUPR-JALAN-NASIONAL",
        "key": "jalan_nasional",
        "institution": "Kementerian Pekerjaan Umum — Direktorat Jenderal Bina Marga (SIGI-PU)",
        "title": "Jaringan Jalan Nasional Indonesia (ast_bm_jalan_nasional_iri)",
        "base_url": "https://sigi.pu.go.id/serverpu/rest/services/Hosted/ast_bm_jalan_nasional_iri/FeatureServer/0",
        "out_fields": "objectid,nm_ruas,kd_ruas,nm_lintas,kd_prov,kab_kot,fungsi,panjang,mantap_psn",
        "order_by": "objectid",
        "page_size": 300,
        "output_file": "jalan_nasional_bina_marga.geojson",
        "meta_file": "service_metadata_jalan_nasional.json",
        "geographic_resolution": "ruas jalan nasional seluruh Indonesia (polyline WGS84 / EPSG:4326)",
        "unit": "koordinat EPSG:4326 (derajat); panjang ruas (km); mantap_psn (%)",
    },
    {
        "source_id": "SRC-PUPR-BPJT-TOL-OPERASI",
        "key": "jalan_tol",
        "institution": "Kementerian Pekerjaan Umum — Badan Pengatur Jalan Tol (BPJT / SIGI-PU)",
        "title": "Jaringan Jalan Tol Operasi Indonesia (ast_bpjt_tol_operasi_v2)",
        "base_url": "https://sigi.pu.go.id/serverpu/rest/services/Hosted/ast_bpjt_tol_operasi_v2/FeatureServer/0",
        "out_fields": "id,objectid,kodefikasi,nama,ruas,jenis,status,sub_status,SHAPE__Length",
        "order_by": "id",
        "page_size": 300,
        "output_file": "jalan_tol_bpjt_operasi.geojson",
        "meta_file": "service_metadata_jalan_tol.json",
        "geographic_resolution": "ruas jalan tol operasional seluruh Indonesia (polyline WGS84 / EPSG:4326)",
        "unit": "koordinat EPSG:4326 (derajat); SHAPE__Length (meter pada proyeksi Indonesia LCC)",
    },
]


def _get_json(url: str, params: dict, source_id: str, retries: int = 5, timeout: int = 120) -> dict:
    last_err = ""
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, timeout=timeout, headers={"User-Agent": USER_AGENT})
            if r.status_code == 200:
                data = r.json()
                if isinstance(data, dict) and "error" in data:
                    raise RuntimeError(f"ArcGIS error: {data['error']}")
                log_access(source_id, r.url, "200", f"{len(r.content)}B")
                return data
            last_err = f"HTTP {r.status_code}"
            log_access(source_id, r.url, str(r.status_code), r.text[:200])
        except Exception as exc:
            last_err = repr(exc)
            log_access(source_id, url, "error", last_err[:200])
        time.sleep(min(2.0 * (2 ** attempt), 20.0))
    raise RuntimeError(f"Failed fetching {url}: {last_err}")


def _epoch_ms_to_iso(ms: int | float | None) -> str:
    if not ms:
        return "unknown"
    return dt.datetime.fromtimestamp(float(ms) / 1000.0, tz=dt.timezone.utc).strftime("%Y-%m-%d")


def fetch_service(spec: dict, refresh: bool = False) -> dict:
    out_path = RAW_DIR / spec["output_file"]
    meta_path = RAW_DIR / spec["meta_file"]
    RAW_DIR.mkdir(parents=True, exist_ok=True)

    if meta_path.exists() and not refresh:
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
    else:
        meta = _get_json(spec["base_url"], {"f": "pjson"}, spec["source_id"])
        meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        time.sleep(0.5)

    if out_path.exists() and not refresh:
        fc = json.loads(out_path.read_text(encoding="utf-8"))
        feat_count = len(fc.get("features", []))
        print(f"Cache hit: {out_path.name} ({feat_count} features)")
    else:
        count_resp = _get_json(
            spec["base_url"] + "/query",
            {"where": "1=1", "returnCountOnly": "true", "f": "json"},
            spec["source_id"],
        )
        expected = int(count_resp.get("count", 0))
        print(f"Fetching {spec['key']} ({expected} expected features) from {spec['base_url']}...")

        features: list[dict] = []
        offset = 0
        page_size = int(spec["page_size"])
        while True:
            page = _get_json(
                spec["base_url"] + "/query",
                {
                    "where": "1=1",
                    "outFields": spec["out_fields"],
                    "outSR": "4326",
                    "orderByFields": spec["order_by"],
                    "resultOffset": str(offset),
                    "resultRecordCount": str(page_size),
                    "f": "geojson",
                },
                spec["source_id"],
            )
            batch = page.get("features", [])
            if not batch:
                break
            features.extend(batch)
            print(f"  {spec['key']}: fetched {len(features)}/{expected} features...")
            offset += len(batch)
            if len(batch) < page_size and (expected == 0 or len(features) >= expected):
                break
            time.sleep(0.45)

        fc = {
            "type": "FeatureCollection",
            "name": spec["key"],
            "features": features,
        }
        tmp = out_path.with_suffix(".geojson.part")
        tmp.write_text(json.dumps(fc, separators=(",", ":"), ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
        tmp.replace(out_path)
        feat_count = len(features)
        print(f"Saved {out_path.name}: {feat_count} features ({out_path.stat().st_size / (1024 * 1024):.2f} MB)")

    last_edit_ms = (meta.get("editingInfo") or {}).get("lastEditDate")
    pub_date = _epoch_ms_to_iso(last_edit_ms)
    return {
        "source_id": spec["source_id"],
        "institution": spec["institution"],
        "title": spec["title"],
        "url": spec["base_url"],
        "publication_date": pub_date,
        "retrieved_at": utc_now(),
        "geographic_resolution": spec["geographic_resolution"],
        "reference_period": pub_date[:4] if pub_date != "unknown" else "2025",
        "unit": spec["unit"],
        "status": "verified_ingested",
        "license_or_terms": "Public ArcGIS Feature Service hosted by Kementerian Pekerjaan Umum (SIGI-PU / Pusdatin); attribution retained.",
        "feature_count": feat_count,
        "raw_file": spec["output_file"],
        "raw_sha256": sha256_file(out_path),
        "raw_bytes": out_path.stat().st_size,
        "meta_file": spec["meta_file"],
        "meta_sha256": sha256_file(meta_path),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true", help="Re-download raw GeoJSON even if cached")
    args = parser.parse_args()

    entries = [fetch_service(spec, refresh=args.refresh) for spec in SERVICES]
    manifest = {
        "schema": "nusantara.raw_manifest/1",
        "retrieved_at": utc_now(),
        "datasets": entries,
    }
    manifest_path = RAW_DIR / "MANIFEST.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote {manifest_path.relative_to(REPO_ROOT)} with {len(entries)} datasets.")


if __name__ == "__main__":
    main()
