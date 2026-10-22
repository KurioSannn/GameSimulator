"""BPS WebAPI connector (SRC-BPS-WEBAPI).

Requires a human-registered key in .env (BPS_API_KEY=...). Without a key this module refuses to
run; it never scrapes www.bps.go.id (bot-protected; we do not bypass access controls).

Two stages, kept separate on purpose:
  fetch  -> raw JSON captured unchanged under data/raw/bps/<domain>/var_<id>[_th_<th>].json
  parse  -> list of observation dicts (data/schemas/observation.schema.json); no interpretation

URL pattern (WebAPI v1 "list" model), per BPS developer documentation and its official SDKs:
  https://webapi.bps.go.id/v1/api/list/model/<model>/lang/ind/domain/<domain>/[var/<id>/][th/<th>/]key/<key>/
Domain codes: "0000" national, "PP00" province (data rows per kab/kota appear as `vervar`).

Usage:
  python3 scripts/connectors/bps_webapi.py discover --domain 3200 --keyword "pembangunan manusia"
  python3 scripts/connectors/bps_webapi.py fetch --domain 3200 --var <id> [--th <th>]
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.fetch import REPO_ROOT, fetch_to_file, utc_now  # noqa: E402

SOURCE_ID = "SRC-BPS-WEBAPI"
BASE = "https://webapi.bps.go.id/v1/api/list"
RAW_DIR = REPO_ROOT / "data/raw/bps"


class BpsFormatError(ValueError):
    """Raised when a response does not match the expected structure. Never guess."""


def load_key() -> str:
    key = os.environ.get("BPS_API_KEY", "")
    env = REPO_ROOT / ".env"
    if not key and env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            if line.strip().startswith("BPS_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not key:
        raise SystemExit("BPS_API_KEY missing: register at https://webapi.bps.go.id/developer/ and add it to .env")
    return key


def url(model: str, domain: str, key: str, **extra: str) -> str:
    parts = [BASE, "model", model, "lang", "ind", "domain", domain]
    for k, v in extra.items():
        parts += [k, str(v)]
    parts += ["key", key]
    return "/".join(parts) + "/"


def fetch_var(domain: str, var: str, th: str | None = None, refresh: bool = False) -> Path:
    key = load_key()
    extra = {"var": var} | ({"th": th} if th else {})
    name = f"var_{var}" + (f"_th_{th}" if th else "") + ".json"
    dest = RAW_DIR / domain / name
    # Note: the key is part of the URL; we never write the URL with the key into logs or raw files.
    return fetch_to_file(url("data", domain, key, **extra), dest, SOURCE_ID, refresh=refresh, delay_s=1.0)


def bps_kab_code(val: int | str) -> str | None:
    """BPS 4-digit kab/kota code (e.g. 3201) -> Kemendagri-style '32.01'. Province rows ('3200') -> None."""
    s = str(val).strip()
    if not re.fullmatch(r"\d{4}", s) or s.endswith("00"):
        return None
    return f"{s[:2]}.{s[2:]}"


def parse_data(payload: dict, *, obs_variable_id: str, unit: str, domain: str, raw_path: str,
               retrieved_at: str, turvar_label: str | None = None, period_from_label=None) -> list[dict]:
    """Parse a WebAPI `data` response into observations.

    datacontent keys are the concatenation vervar|var|turvar|tahun|turtahun (no separators).
    We decompose by trying every combination of the declared code lists and REQUIRE each
    key to match exactly one combination; otherwise BpsFormatError.
    """
    if payload.get("status") != "OK" or payload.get("data-availability") not in (None, "available"):
        raise BpsFormatError(f"response not OK/available: status={payload.get('status')} avail={payload.get('data-availability')}")
    try:
        var_ids = [str(v["val"]) for v in payload["var"]]
        vervars = {str(v["val"]): v["label"] for v in payload["vervar"]}
        turvars = {str(v["val"]): v["label"] for v in payload.get("turvar", [])} or {"0": ""}
        tahuns = {str(v["val"]): v["label"] for v in payload["tahun"]}
        turtahuns = {str(v["val"]): v["label"] for v in payload.get("turtahun", [])} or {"0": ""}
        content: dict = payload["datacontent"]
    except (KeyError, TypeError) as e:
        raise BpsFormatError(f"missing field: {e}") from e
    if len(var_ids) != 1:
        raise BpsFormatError(f"expected exactly one var, got {var_ids}")
    if turvar_label is None and len(turvars) > 1:
        raise BpsFormatError(f"multiple turvar categories {list(turvars.values())}; specify turvar_label")

    combos = {}
    for vv, tv, th, tt in itertools.product(vervars, turvars, tahuns, turtahuns):
        combos.setdefault(f"{vv}{var_ids[0]}{tv}{th}{tt}", []).append((vv, tv, th, tt))
    ambiguous = [k for k, v in combos.items() if len(v) > 1]
    if ambiguous:
        raise BpsFormatError(f"ambiguous datacontent key decomposition: {ambiguous[:3]}")

    out = []
    for k, raw_val in content.items():
        if k not in combos:
            raise BpsFormatError(f"datacontent key {k} does not decompose into declared codes")
        vv, tv, th, tt = combos[k][0]
        if turvar_label is not None and turvars[tv] != turvar_label:
            continue
        region = bps_kab_code(vv)
        if region is None:
            continue  # province/national aggregate row inside a kab/kota table; parsed separately if needed
        year_label = tahuns[th]
        period = period_from_label(year_label, turtahuns[tt]) if period_from_label else str(year_label)
        row = {
            "obs_variable_id": obs_variable_id, "region_id": region, "resolution": "kabkota",
            "reference_period": period, "unit": unit, "source_id": SOURCE_ID,
            "dataset_ref": f"bps:domain={domain};var={var_ids[0]};turvar={tv};th={th};turth={tt}",
            "source_label": vervars[vv], "retrieved_at": retrieved_at, "raw_path": raw_path,
            "fact_class": "REAL_OFFICIAL",
        }
        if raw_val is None or (isinstance(raw_val, str) and raw_val.strip() in ("", "-", "…", "...")):
            row["value"] = None
            row["missing_class"] = "NOT_PUBLISHED"
        else:
            try:
                row["value"] = float(raw_val)
            except (TypeError, ValueError) as e:
                raise BpsFormatError(f"non-numeric value {raw_val!r} at {k}") from e
        out.append(row)
    return out


def discover(domain: str, keyword: str) -> list[dict]:
    """Search variables in a domain by keyword (paginated `var` model). Returns [{var_id, title, unit}]."""
    key = load_key()
    found, page = [], 1
    while True:
        dest = RAW_DIR / domain / "_var_index" / f"page_{page}.json"
        fetch_to_file(url("var", domain, key, page=page), dest, SOURCE_ID, delay_s=1.0)
        d = json.loads(dest.read_text(encoding="utf-8"))
        if d.get("status") != "OK" or not isinstance(d.get("data"), list) or len(d["data"]) < 2:
            break
        meta, rows = d["data"][0], d["data"][1]
        for r in rows:
            if keyword.lower() in str(r.get("title", "")).lower():
                found.append({"var_id": r.get("var_id"), "title": r.get("title"), "unit": r.get("unit")})
        if page >= int(meta.get("pages", 1)):
            break
        page += 1
    return found


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("discover")
    d.add_argument("--domain", required=True)
    d.add_argument("--keyword", required=True)
    f = sub.add_parser("fetch")
    f.add_argument("--domain", required=True)
    f.add_argument("--var", required=True)
    f.add_argument("--th")
    a = ap.parse_args()
    if a.cmd == "discover":
        print(json.dumps(discover(a.domain, a.keyword), ensure_ascii=False, indent=1))
    else:
        print(fetch_var(a.domain, a.var, a.th))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
