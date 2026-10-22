"""Shared helpers for the NUSANTARA research pipeline.

Stdlib only, so the pipeline runs on a clean Python 3.10+ install.

Raw-capture contract (docs/04_DATA_RESEARCH_SPEC.md, AGENTS.md):
- every download lands under data/raw/<source_id>/<snapshot_id>/
- raw files are never overwritten; a re-run with the same snapshot reuses the cache
- every file gets a <name>.meta.json sidecar (url, retrieved_at, sha256, http status)
- every request attempt (success or failure) is appended to the access log
"""

from __future__ import annotations

import csv
import hashlib
import json
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[4]  # scripts/pipelines/geo/v2/ -> repo root
DATA_RAW = REPO_ROOT / "data" / "raw"
DATA_NORMALIZED = REPO_ROOT / "data" / "normalized"
DATA_CATALOG = REPO_ROOT / "data" / "catalog"
ACCESS_LOG = DATA_CATALOG / "source_access_log.csv"

USER_AGENT = "NUSANTARA-research/0.1 (offline educational game research; low-rate)"
MIN_INTERVAL_S = 1.0  # polite delay between live requests to the same pipeline run
MAX_RETRIES = 4

_last_request_at = 0.0


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def log_access(source_id: str, url: str, status: str, http_code: int | None,
               note: str = "", path: str = "", sha256: str = "") -> None:
    ACCESS_LOG.parent.mkdir(parents=True, exist_ok=True)
    new = not ACCESS_LOG.exists()
    with ACCESS_LOG.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["timestamp_utc", "source_id", "url", "status", "http_code",
                        "raw_path", "sha256", "note"])
        w.writerow([utc_now_iso(), source_id, url, status, http_code or "", path, sha256, note])


def _http_get(url: str, timeout: int) -> tuple[int, bytes, str]:
    global _last_request_at
    wait = MIN_INTERVAL_S - (time.monotonic() - _last_request_at)
    if wait > 0:
        time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, resp.read(), resp.headers.get("Content-Type", "")
    finally:
        _last_request_at = time.monotonic()


def fetch_raw(source_id: str, snapshot_id: str, name: str, url: str,
              timeout: int = 120, validate=None) -> Path:
    """Download `url` into the immutable raw store, or return the cached copy.

    `validate(bytes)` may raise ValueError to reject a payload (e.g. an ArcGIS
    error object served with HTTP 200); rejected payloads are retried, then
    logged as failures and never written to the raw store.
    """
    out = DATA_RAW / source_id / snapshot_id / name
    meta_path = out.with_name(out.name + ".meta.json")
    if out.exists() and meta_path.exists():
        return out

    last_err = ""
    for attempt in range(1, MAX_RETRIES + 1):
        code = None
        try:
            code, body, ctype = _http_get(url, timeout)
            if validate:
                validate(body)
        except (urllib.error.URLError, TimeoutError, ValueError, ConnectionError) as e:
            code = getattr(e, "code", code)
            last_err = f"{type(e).__name__}: {e}"
            log_access(source_id, url, "retry" if attempt < MAX_RETRIES else "failed",
                       code, f"attempt {attempt}: {last_err}")
            if isinstance(e, urllib.error.HTTPError) and 400 <= e.code < 500 and e.code != 429:
                break  # client errors will not fix themselves
            time.sleep(2 ** attempt)
            continue

        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(body)
        digest = sha256_bytes(body)
        meta = {
            "source_id": source_id,
            "snapshot_id": snapshot_id,
            "url": url,
            "retrieved_at": utc_now_iso(),
            "http_status": code,
            "content_type": ctype,
            "bytes": len(body),
            "sha256": digest,
        }
        meta_path.write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        log_access(source_id, url, "ok", code, "", str(out.relative_to(REPO_ROOT)), digest)
        return out

    raise RuntimeError(f"fetch failed for {url}: {last_err}")


def arcgis_validate(body: bytes) -> None:
    """ArcGIS REST returns HTTP 200 with an {"error": ...} body on failure."""
    try:
        doc = json.loads(body)
    except json.JSONDecodeError as e:
        raise ValueError(f"not JSON: {e}") from e
    if isinstance(doc, dict) and "error" in doc:
        raise ValueError(f"ArcGIS error: {doc['error']}")


def json_validate(body: bytes) -> None:
    try:
        json.loads(body)
    except json.JSONDecodeError as e:
        raise ValueError(f"not JSON: {e}") from e
