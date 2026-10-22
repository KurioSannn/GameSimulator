"""Capture BPS provincial "Luas Daerah dan Jumlah Pulau Menurut Kabupaten/Kota" tables (SRC-0008).

These are the independent official area figures used by the LUASWH area-unit
audit (research/reports/2026-10-22_AREA_UNIT_INVESTIGATION.md). BPS tabulates area from
the Kemendagri code/area decree named in each table's `sumber` field.

The table pages are Next.js; the table itself is embedded as JSON in the
flight payload, so raw HTML is captured as-is and parsed offline here.
No robots.txt is served (404) on the province subdomains checked.

Usage:
  python3 scripts/pipelines/geo/v2/fetch_bps_area_tables.py [--year 2025]
Writes data/processed/geography/<snapshot>/bps_area_tables_<year>.json
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.error

from common import DATA_RAW, REPO_ROOT, fetch_raw, log_access, utc_now_iso

SOURCE_ID = "SRC-0008"
TABLE_ID = "VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw=="
# BPS province subdomains. The four 2022 Papua provinces have no subdomain of
# their own (papuaselatan.bps.go.id does not resolve); their statistics are
# hosted by the papua / papuabarat sites, so coverage is measured, not assumed.
SUBDOMAINS = [
    "aceh", "sumut", "sumbar", "riau", "jambi", "sumsel", "bengkulu", "lampung", "babel", "kepri",
    "jakarta", "jabar", "jateng", "yogyakarta", "jatim", "banten", "bali", "ntb", "ntt",
    "kalbar", "kalteng", "kalsel", "kaltim", "kaltara",
    "sulut", "sulteng", "sulsel", "sultra", "gorontalo", "sulbar",
    "maluku", "malut", "papuabarat", "papua",
]
AREA_LABEL = "Luas Wilayah"


def table_url(sub: str, year: int) -> str:
    return f"https://{sub}.bps.go.id/id/statistics-table/3/{TABLE_ID}/luas-daerah-dan-jumlah-pulau.html?year={year}"


def extract_table(html: str) -> dict:
    chunks = [json.loads('"' + m + '"') for m in
              re.findall(r'self\.__next_f\.push\(\[1,"((?:[^"\\]|\\.)*)"\]\)', html)]
    text = "".join(chunks)
    i = text.find('{"change_log"')
    if i < 0:
        raise ValueError("table JSON not found in page")
    obj, _ = json.JSONDecoder().raw_decode(text[i:])
    return obj


def parse_number_id(s: str | None):
    """BPS Indonesian formatting: '.' thousands, ',' decimal. Returns None for '–', '...', etc."""
    if s is None:
        return None
    s = s.strip()
    if not re.fullmatch(r"[0-9.]+(,[0-9]+)?", s):
        return None
    return float(s.replace(".", "").replace(",", "."))


def strip_html(s: str | None) -> str:
    s = (s or "").replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", s)).strip()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--year", type=int, default=2025)
    ap.add_argument("--only", nargs="*", help="subset of subdomains (e.g. retry with an older --year)")
    args = ap.parse_args()

    tables = []
    for sub in args.only or SUBDOMAINS:
        url = table_url(sub, args.year)
        try:
            path = fetch_raw(SOURCE_ID, args.snapshot, f"luas_daerah_{sub}_{args.year}.html", url)
        except (RuntimeError, urllib.error.URLError) as e:
            print(f"{sub}: FAILED {e}")
            tables.append({"subdomain": sub, "url": url, "status": "fetch_failed", "error": str(e)})
            continue
        try:
            t = extract_table(path.read_text(encoding="utf-8"))
        except ValueError as e:
            log_access(SOURCE_ID, url, "parse_failed", None, str(e), str(path.relative_to(REPO_ROOT)))
            print(f"{sub}: PARSE FAILED {e}")
            tables.append({"subdomain": sub, "url": url, "status": "parse_failed", "error": str(e)})
            continue
        area_cols = [k for k, c in t["kolom"].items() if c.get("nama_variabel") == AREA_LABEL]
        if len(area_cols) != 1:
            tables.append({"subdomain": sub, "url": url, "status": "unexpected_columns",
                           "columns": {k: c.get("nama_variabel") for k, c in t["kolom"].items()}})
            print(f"{sub}: unexpected columns")
            continue
        col = area_cols[0]
        rows = [{
            "label": r["label"],
            "kode_wilayah_bps": str(r["kode_wilayah"]),
            "area_value_raw": r["variables"][col]["value_raw"] or r["variables"][col]["value"],
            "area_value": parse_number_id(r["variables"][col]["value_raw"]),
        } for r in t["data"]]
        tables.append({
            "subdomain": sub, "url": url, "status": "ok",
            "raw_path": str(path.relative_to(REPO_ROOT)),
            "title": t["judul_tabel"], "tahun_data": t["tahun_data"],
            "penanggung_jawab": t["penanggung_jawab"],
            "area_unit": strip_html(t["kolom"][col].get("satuan")),
            "sumber": strip_html(t.get("sumber")), "catatan": strip_html(t.get("catatan")),
            "table_created": t.get("table_created"), "available_years": t.get("list_tahun_data"),
            "rows": rows,
        })
        print(f"{sub}: {t['tahun_data']} rows={len(rows)} unit={strip_html(t['kolom'][col].get('satuan'))} | {strip_html(t.get('sumber'))[:90]}")

    out = REPO_ROOT / "data" / "processed" / "geography" / args.snapshot / (f"bps_area_tables_{args.year}" + (f"_{'-'.join(args.only)}" if args.only else "") + ".json")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"source_id": SOURCE_ID, "parsed_at": utc_now_iso(), "year_requested": args.year,
                               "tables": tables}, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"-> {out.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
