"""BNPB open-data portal connector (CKAN at data.bnpb.go.id), via the documented Action API.

Uses only `package_show` and `datastore_search` (JSON). Direct file downloads on this portal
return a Cloudflare bot challenge; we never try to pass it. Raw API responses are archived
unchanged under data/raw/bnpb/ckan/<package>/<resource_id>.json with a MANIFEST (checksums).
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.fetch import REPO_ROOT, USER_AGENT, log_access, sha256_file, utc_now  # noqa: E402

SOURCE_ID = "SRC-BNPB-CKAN"
API = "https://data.bnpb.go.id/api/3/action"
RAW = REPO_ROOT / "data/raw/bnpb/ckan"


def _get(action: str, params: dict, retries: int = 6) -> dict:
    last = ""
    for attempt in range(retries):
        try:
            r = requests.get(f"{API}/{action}", params=params, timeout=60, headers={"User-Agent": USER_AGENT})
            if r.status_code == 200 and r.headers.get("content-type", "").startswith("application/json"):
                d = r.json()
                if d.get("success"):
                    time.sleep(1.0)
                    return d["result"]
                last = f"success=false: {str(d.get('error'))[:200]}"
            else:
                last = f"HTTP {r.status_code} {r.headers.get('content-type', '')}"
        except (requests.RequestException, ValueError) as e:
            last = repr(e)
        time.sleep(min(60, 5 * 2 ** attempt))
    log_access(SOURCE_ID, f"{API}/{action}?{params}", "failed", last)
    raise RuntimeError(f"CKAN {action} failed: {last}")


def package(package_id: str) -> dict:
    return _get("package_show", {"id": package_id})


def fetch_resource_records(package_id: str, resource: dict, refresh: bool = False) -> Path:
    """All DataStore records of a resource -> raw JSON file (fields + records + resource metadata)."""
    dest = RAW / package_id / f"{resource['id']}.json"
    if dest.exists() and not refresh:
        return dest
    if not resource.get("datastore_active"):
        raise RuntimeError(f"resource {resource['id']} is not in the DataStore")
    records, fields, offset, total = [], None, 0, None
    while total is None or offset < total:
        res = _get("datastore_search", {"resource_id": resource["id"], "limit": 500, "offset": offset})
        fields = res["fields"]
        total = res["total"]
        records += res["records"]
        offset += 500
    dest.parent.mkdir(parents=True, exist_ok=True)
    payload = {"package_id": package_id, "resource": {k: resource.get(k) for k in
               ("id", "name", "format", "created", "last_modified", "url", "datastore_active")},
               "retrieved_at": utc_now(), "api": f"{API}/datastore_search", "fields": fields,
               "total": total, "records": records}
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
    log_access(SOURCE_ID, f"{API}/datastore_search?resource_id={resource['id']}", "ok", f"{len(records)} records")
    return dest


def write_manifest(package_id: str, pkg: dict) -> None:
    d = RAW / package_id
    files = {p.name: {"sha256": sha256_file(p), "bytes": p.stat().st_size} for p in sorted(d.glob("*.json")) if p.name != "MANIFEST.json"}
    manifest = {"source_id": SOURCE_ID, "package_id": package_id, "title": pkg.get("title"),
                "organization": (pkg.get("organization") or {}).get("title"), "license": pkg.get("license_title"),
                "metadata_modified": pkg.get("metadata_modified"), "retrieved_at": utc_now(), "files": files}
    (d / "MANIFEST.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
