"""Shared polite HTTP fetching with caching, retry/backoff, checksums and an access log.

Every raw capture is written once and never modified. Re-running a pipeline
skips files that already exist (cache hit) unless --refresh is passed.
"""
from __future__ import annotations

import datetime as _dt
import hashlib
import json
import time
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parents[2]
ACCESS_LOG = REPO_ROOT / "research" / "sources" / "access_log.jsonl"
USER_AGENT = "NUSANTARA-research-pipeline/0.1 (offline game research; contact via project repo)"


def utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def log_access(source_id: str, url: str, status: str, detail: str = "") -> None:
    ACCESS_LOG.parent.mkdir(parents=True, exist_ok=True)
    rec = {"at": utc_now(), "source_id": source_id, "url": url, "status": status, "detail": detail}
    with ACCESS_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def fetch_to_file(
    url: str,
    dest: Path,
    source_id: str,
    *,
    params: dict | None = None,
    refresh: bool = False,
    retries: int = 5,
    timeout: int = 180,
    delay_s: float = 1.0,
) -> Path:
    """Download url to dest unless cached. Raises after exhausting retries (caller records failure)."""
    if dest.exists() and not refresh:
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    last_err = ""
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, timeout=timeout, headers={"User-Agent": USER_AGENT})
            if r.status_code == 200:
                tmp.write_bytes(r.content)
                tmp.replace(dest)
                time.sleep(delay_s)  # be polite to public government servers
                return dest
            last_err = f"HTTP {r.status_code}"
        except requests.RequestException as e:
            last_err = repr(e)
        time.sleep(min(60, delay_s * (2 ** attempt)))
    log_access(source_id, url, "failed", last_err)
    raise RuntimeError(f"fetch failed after {retries} attempts: {url} ({last_err})")
