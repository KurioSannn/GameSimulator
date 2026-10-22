"""Year-by-year registry of BNPB "Jumlah kejadian dan dampak bencana" datasets (2000-2025).

Discovery source: BNPB Satu Data portal (CKAN Action API, package_show). For each year it records
dataset title, organization, license, resource title/URL/format, DataStore availability, and a
retrieval status:

  API_AVAILABLE              resource rows retrievable through the DataStore API
  MANUAL_DOWNLOAD_REQUIRED   resource is a Google Drive file/folder; Drive's robots.txt disallows
                             automated download (we never bypass it). Expected destination listed.
  MANUAL_FILES_PRESENT       files found in the expected manual destination (checksums recorded)
  NOT_FOUND                  no package for that year on the portal

Outputs: research/sources/bnpb_yearly_index.json and .md. No files are downloaded here.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from connectors import bnpb_ckan  # noqa: E402
from lib.fetch import REPO_ROOT, sha256_file, utc_now  # noqa: E402

PORTAL = "https://data.bnpb.go.id/dataset/"
OUT_JSON = REPO_ROOT / "research/sources/bnpb_yearly_index.json"
OUT_MD = REPO_ROOT / "research/sources/bnpb_yearly_index.md"
MANUAL = REPO_ROOT / "data/raw/bnpb/drive_manual"


def package_id(year: int) -> str:
    if year == 2000:
        return "datakejadian2000"
    if year == 2024:
        return "kompilasi-data-jumlah-dan-dampak-kejadian-bencana-2024"
    if year == 2025:
        return "kompilasi-data-kejadian-dan-dampak-bencana-2025"
    return f"jumlah-kejadian-dan-dampak-bencana-tahun-{year}"


def main() -> int:
    entries = []
    for year in range(2000, 2026):
        pid = package_id(year)
        try:
            pkg = bnpb_ckan.package(pid)
        except RuntimeError as e:
            entries.append({"year": year, "package_id": pid, "status": "NOT_FOUND", "error": str(e)[:200]})
            continue
        res = pkg.get("resources", [])
        drive = [r for r in res if "drive.google.com" in (r.get("url") or "")]
        ds = [r for r in res if r.get("datastore_active")]
        kab = [r for r in res if "kabupaten" in (r.get("name") or "").lower() or "stat_by_wil" in (r.get("name") or "").lower()]
        manual_dir = MANUAL / str(year)
        manual_files = sorted(p for p in manual_dir.rglob("*") if p.is_file()) if manual_dir.exists() else []
        if manual_files:
            status = "MANUAL_FILES_PRESENT"
        elif drive:
            status = "MANUAL_DOWNLOAD_REQUIRED"
        elif ds:
            status = "API_AVAILABLE"
        else:
            status = "NO_RETRIEVABLE_RESOURCE"
        entries.append({
            "year": year, "package_id": pid, "dataset_title": pkg.get("title"),
            "organization": (pkg.get("organization") or {}).get("title"), "license": pkg.get("license_title"),
            "metadata_modified": pkg.get("metadata_modified"), "official_source_url": PORTAL + pid,
            "description": (pkg.get("notes") or "")[:300],
            "resources": [{"title": r.get("name"), "url": r.get("url"), "format": r.get("format") or None,
                           "datastore_active": bool(r.get("datastore_active"))} for r in res],
            "n_resources": len(res), "n_datastore": len(ds), "n_drive": len(drive),
            "geographic_resolution": "kabupaten/kota" if (kab or drive) else "unknown (check resources)",
            "variables_documented": "events and impacts by disaster type (per dataset description); exact columns to be confirmed on real files",
            "status": status,
            "expected_manual_destination": str(manual_dir.relative_to(REPO_ROOT)) + "/" if drive else None,
            "manual_files": [{"path": str(p.relative_to(REPO_ROOT)), "sha256": sha256_file(p), "bytes": p.stat().st_size} for p in manual_files],
            "used_for_frequency": 2002 <= year <= 2024,
            "note": ("Excluded from frequency: predates many regency splits and BNPB (2008)." if year < 2002 else
                     "Province level only." if year == 2025 else ""),
        })
    OUT_JSON.write_text(json.dumps({"generated_at": utc_now(), "discovery": "data.bnpb.go.id CKAN package_show", "years": entries},
                                   ensure_ascii=False, indent=1), encoding="utf-8")
    lines = ["# BNPB yearly event & impact datasets: year-by-year registry", "",
             f"Generated {utc_now()} from the BNPB Satu Data portal (CKAN API). No files downloaded by this step.", "",
             "| Year | Status | Dataset title | Org | License | Resources (DataStore / Drive) | Expected manual destination |",
             "|---|---|---|---|---|---|---|"]
    for e in entries:
        lines.append(f"| {e['year']} | **{e['status']}** | {e.get('dataset_title', '—')} | {e.get('organization', '—')} | "
                     f"{e.get('license') or '—'} | {e.get('n_resources', 0)} ({e.get('n_datastore', 0)} / {e.get('n_drive', 0)}) | "
                     f"{e.get('expected_manual_destination') or '—'} |")
    lines += ["", "Drive resource locations (open in a browser, use Download, unzip into the destination):", ""]
    for e in entries:
        for r in e.get("resources", []):
            if "drive.google.com" in (r["url"] or ""):
                lines.append(f"- {e['year']}: {r['url']} → `{e['expected_manual_destination']}`")
    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    from collections import Counter
    print(dict(Counter(e["status"] for e in entries)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
