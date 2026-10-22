"""BNPB recorded disaster events and impacts by kab/kota -> flood observations (REAL_OFFICIAL).

Years and access:
  - 2024: CKAN package `kompilasi-data-jumlah-dan-dampak-kejadian-bencana-2024` (BNPB Pusdatinkom, ODbL),
    14 kab/kota tables in the DataStore (API).
  - 2002-2023: BNPB-linked Google Drive folders; automated download is disallowed by Drive's robots.txt.
    When a human places those files in data/raw/bnpb/drive_manual/<year>/, add a parser here.
    (Not yet implemented: their layout must be inspected on real files first.)

Only the BANJIR column is used for flood variables; other hazards are kept in raw files.
A kab/kota absent from a year's table gets NO observation for that year (absence is not
documented to mean zero events); frequency rules average over the years actually observed.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from connectors import bnpb_ckan  # noqa: E402
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

PACKAGE_2024 = "kompilasi-data-jumlah-dan-dampak-kejadian-bencana-2024"
REG = REPO_ROOT / "data/normalized/regions/region_registry.json"

# Resource name (kab/kota tables) -> (observation variable, unit)
TABLES = {
    "Jumlah Kejadian Bencana Menurut Kabupaten": ("bnpb_flood_events", "kejadian"),
    "Jumlah Korban Meninggal Dunia Akibat Bencana Menurut Kabupaten": ("bnpb_flood_deaths", "jiwa"),
    "Jumlah Korban Hilang Akibat Bencana Menurut Kabupaten": ("bnpb_flood_missing", "jiwa"),
    "Jumlah Korban Luka / Sakit Akibat Bencana Menurut Kabupaten": ("bnpb_flood_injured", "jiwa"),
    "Jumlah Korban Terdampak Akibat Bencana Menurut Kabupaten": ("bnpb_flood_affected", "jiwa"),
    "Jumlah Korban Mengungsi Akibat Bencana Menurut Kabupaten": ("bnpb_flood_displaced", "jiwa"),
    "Jumlah Rumah Rusak Akibat Bencana Menurut Kabupaten": ("bnpb_flood_houses_damaged", "unit rumah"),
    "Jumlah Satuan Pendidikan Rusak Akibat Bencana Menurut Kabupaten": ("bnpb_flood_schools_damaged", "unit"),
    "Jumlah Fasilitas Pelayanan Kesehatan yang Rusak Akibat Bencana Menurut Kabupaten": ("bnpb_flood_health_facilities_damaged", "unit"),
    "Jumlah jembatan Rusak Akibat Bencana Menurut Kabupaten": ("bnpb_flood_bridges_damaged", "unit"),
}


def norm(s: str) -> str:
    s = s.upper()
    s = re.sub(r"^(KABUPATEN ADMINISTRASI|KABUPATEN|KAB\.|KOTA ADMINISTRASI|KOTA ADM\.|ADM\.)\s+", "", s)
    return re.sub(r"[^A-Z0-9]", "", s)


def write_validation(out: dict[str, list[dict]]) -> None:
    """Compare kab/kota sums with BNPB's own national ('INDONESIA') rows. Differences are recorded,
    never reconciled (G-16)."""
    lines = ["# BNPB 2024 flood tables: internal consistency", "", f"Generated {utc_now()}.", "",
             "| Observation | Sum of kab/kota rows | BNPB national row (INDONESIA) | Difference | Status |",
             "|---|---:|---:|---:|---|"]
    for var, rows in out.items():
        raw_path = REPO_ROOT / rows[0]["raw_path"] if rows else None
        national = None
        if raw_path and raw_path.exists():
            for rec in json.loads(raw_path.read_text(encoding="utf-8"))["records"]:
                if str(rec.get("Nama Kabupaten/Kota", "")).strip().upper() == "INDONESIA" and rec.get("BANJIR") is not None:
                    national = float(rec["BANJIR"])
        total = sum(r["value"] for r in rows if r.get("value") is not None)
        if national is None:
            lines.append(f"| `{var}` | {total:,.0f} | (no national row in table) | — | — |")
        else:
            diff = total - national
            status = "consistent" if diff == 0 else "UNRESOLVED SOURCE DISCREPANCY (kept as published; G-16)"
            lines.append(f"| `{var}` | {total:,.0f} | {national:,.0f} | {diff:+,.0f} | {status} |")
    lines += ["", "Possible explanations (not verified): events spanning several kab/kota counted once per kab/kota; "
              "late corrections applied to one table only. No values were altered."]
    path = REPO_ROOT / "research/reports/validation/bnpb_2024_consistency.md"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    reg = {r["region_id"]: r for r in json.loads(REG.read_text(encoding="utf-8"))["kabkota"]}
    pkg = bnpb_ckan.package(PACKAGE_2024)
    out: dict[str, list[dict]] = {}
    issues: list[str] = []
    for res in pkg["resources"]:
        key = next((k for k in TABLES if res["name"].lower().startswith(k.lower())), None)
        if key is None:
            continue
        var, unit = TABLES[key]
        raw_path = bnpb_ckan.fetch_resource_records(PACKAGE_2024, res)
        payload = json.loads(raw_path.read_text(encoding="utf-8"))
        rows = []
        for rec in payload["records"]:
            if rec.get("Kode Wilayah Kabupaten / Kota") is None:
                if str(rec.get("Nama Kabupaten/Kota", "")).strip().upper() == "INDONESIA":
                    continue  # national total row (kept in raw; not a kab/kota observation)
                issues.append(f"{var}: row without code: {rec}")
                continue
            code_raw = str(int(float(rec["Kode Wilayah Kabupaten / Kota"])))
            if not re.fullmatch(r"\d{4}", code_raw):
                issues.append(f"{var}: bad code {code_raw}")
                continue
            rid = f"{code_raw[:2]}.{code_raw[2:]}"
            name = str(rec["Nama Kabupaten/Kota"])
            if rid not in reg:
                issues.append(f"{var}: code {rid} ({name}) not in registry")
                continue
            r = reg[rid]
            reg_names = {norm(n) for n in (r["name"], r["name_big"], r.get("name_kemendagri_secondary") or "") if n}
            if norm(name) not in reg_names and norm("KOTA " + name) not in reg_names and norm(name.replace("KOTA ", "")) not in {x.replace("KOTA", "", 1) for x in reg_names}:
                issues.append(f"{var}: name check {rid}: BNPB '{name}' vs registry '{r['name']}' (kept: code is authoritative)")
            v = rec.get("BANJIR")
            row = {"obs_variable_id": var, "region_id": rid, "resolution": "kabkota", "reference_period": "2024",
                   "unit": unit, "source_id": "SRC-BNPB-CKAN",
                   "dataset_ref": f"bnpb-ckan:{PACKAGE_2024}:{res['id']}:BANJIR", "source_label": name,
                   "retrieved_at": payload["retrieved_at"], "raw_path": str(raw_path.relative_to(REPO_ROOT)),
                   "fact_class": "REAL_OFFICIAL"}
            if v is None or str(v).strip() in ("", "-"):
                row.update(value=None, missing_class="NOT_PUBLISHED")
            else:
                row["value"] = float(v)
            rows.append(row)
        out[var] = rows
    bnpb_ckan.write_manifest(PACKAGE_2024, pkg)
    write_validation(out)
    for var, rows in out.items():
        observations.write(var, rows)
        print(f"{var}: {sum(r.get('value') is not None for r in rows)} kab/kota (2024)")
    name_notes = [i for i in issues if i.startswith(tuple(v for v, _ in TABLES.values())) and "name check" in i]
    hard = [i for i in issues if "name check" not in i]
    if name_notes:
        print(f"name differences (code kept, {len(name_notes)}):\n  " + "\n  ".join(sorted(set(n.split(': ', 1)[1] for n in name_notes))[:30]))
    if hard:
        print("ERRORS:\n  " + "\n  ".join(hard))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
