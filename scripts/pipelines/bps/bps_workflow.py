"""BPS ingestion workflow with enforced order: check -> inventory -> confirm -> sample -> bulk.

  check      verify a real BPS_API_KEY is configured (.env, gitignored) and the API answers
  inventory  search variables by keyword in the national domain and one sample province domain;
             writes research/sources/bps_inventory.json (raw API pages archived under data/raw/bps/)
  sample     fetch ONE indicator for ONE province domain, parse with the strict parser, print rows
             for manual comparison against the published BPS table
  bulk       ingest approved indicators for all 38 province domains -> observations
             REFUSES unless data/calibration/bps_indicators.json marks the indicator fully confirmed
             (var_id, title, unit, year, level, region_coding, domain_scope) and sample_checked=true

No key is ever estimated or embedded. Without BPS_API_KEY every command exits with instructions.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from connectors import bps_webapi  # noqa: E402
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

APPROVALS = REPO_ROOT / "data/calibration/bps_indicators.json"
INVENTORY = REPO_ROOT / "research/sources/bps_inventory.json"
REQUIRED = ("var_id", "title", "unit", "year", "level", "region_coding", "domain_scope")
SAMPLE_DOMAIN = "3200"  # Jawa Barat


def province_domains() -> list[str]:
    reg = json.loads((REPO_ROOT / "data/normalized/regions/region_registry.json").read_text(encoding="utf-8"))
    return [p["region_id"] + "00" for p in reg["provinces"]]


def approved(ind: dict) -> tuple[bool, list[str]]:
    missing = [k for k in REQUIRED if not ind.get(k)]
    if not ind.get("sample_checked"):
        missing.append("sample_checked")
    return (not missing, missing)


def cmd_check() -> int:
    bps_webapi.load_key()  # exits with instructions if absent
    print("BPS_API_KEY present (value not printed). Next: inventory.")
    return 0


def cmd_inventory() -> int:
    appr = json.loads(APPROVALS.read_text(encoding="utf-8"))["indicators"]
    inv = {"generated_at": utc_now(), "domains": ["0000", SAMPLE_DOMAIN], "results": {}}
    for oid, ind in appr.items():
        inv["results"][oid] = {d: bps_webapi.discover(d, ind["keyword"]) for d in inv["domains"]}
        print(f"{oid}: " + ", ".join(f"{d}={len(v)} matches" for d, v in inv["results"][oid].items()))
    INVENTORY.write_text(json.dumps(inv, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"wrote {INVENTORY.relative_to(REPO_ROOT)}. Confirm meaning/unit/year/level/coding, fill {APPROVALS.relative_to(REPO_ROOT)}, then run sample.")
    return 0


def _parse(domain: str, oid: str, ind: dict, th: str | None) -> list[dict]:
    raw = bps_webapi.fetch_var(domain, str(ind["var_id"]), th)
    payload = json.loads(raw.read_text(encoding="utf-8"))
    return bps_webapi.parse_data(payload, obs_variable_id=oid, unit=str(ind["unit"]), domain=domain,
                                 raw_path=str(raw.relative_to(REPO_ROOT)), retrieved_at=utc_now(),
                                 turvar_label=ind.get("turvar_label"))


def cmd_sample(oid: str, th: str | None) -> int:
    ind = json.loads(APPROVALS.read_text(encoding="utf-8"))["indicators"][oid]
    if not ind.get("var_id") or not ind.get("unit"):
        raise SystemExit(f"{oid}: fill var_id and unit from the inventory first")
    rows = _parse(SAMPLE_DOMAIN, oid, ind, th)
    observations.validate(rows)
    for r in rows[:30]:
        print(r["region_id"], r["source_label"], r["reference_period"], r.get("value"), r["unit"])
    print(f"{len(rows)} rows. Compare with the published BPS table; then set sample_checked=true.")
    return 0


def cmd_bulk(only: list[str] | None) -> int:
    appr = json.loads(APPROVALS.read_text(encoding="utf-8"))["indicators"]
    todo = {k: v for k, v in appr.items() if not only or k in only}
    refused = {k: approved(v)[1] for k, v in todo.items() if not approved(v)[0]}
    if refused:
        for k, miss in refused.items():
            print(f"REFUSED {k}: not confirmed ({', '.join(miss)})")
        return 2
    for oid, ind in todo.items():
        rows = []
        for d in province_domains():
            rows += _parse(d, oid, ind, str(ind["year"]))
        observations.write(oid, rows)
        print(f"{oid}: {len(rows)} rows")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("check")
    sub.add_parser("inventory")
    s = sub.add_parser("sample")
    s.add_argument("indicator")
    s.add_argument("--th")
    b = sub.add_parser("bulk")
    b.add_argument("--only", nargs="*")
    a = ap.parse_args()
    if a.cmd == "check":
        return cmd_check()
    if a.cmd == "inventory":
        return cmd_inventory()
    if a.cmd == "sample":
        return cmd_sample(a.indicator, a.th)
    return cmd_bulk(a.only)


if __name__ == "__main__":
    raise SystemExit(main())
