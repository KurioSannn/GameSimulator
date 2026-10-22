"""BNPB IRBI 2024 (Indeks Risiko Bencana Indonesia) -> observations (REAL_OFFICIAL).

Source: SRC-BNPB-IRBI-2024, "BUKU IRBI 2024", PDF hosted by BNPB on inarisk.bnpb.go.id.
Tables parsed (text layer, no OCR):
  - multi-hazard ranking "SKOR / KELAS RISIKO" (all 514 kab/kota)      -> obs `official_irbi_total_score`
  - "INDEKS RISIKO BENCANA BANJIR TAHUN 2024" (397 kab/kota listed)     -> obs `official_irbi_flood_score`
Kab/kota absent from the flood table are recorded as missing (NOT_PUBLISHED), never as 0: the book
does not state (in the text we parsed) that absence means "no flood risk".

The IRBI score is a RISK index (hazard x vulnerability / capacity, BNPB method), not pure hazard.
How it is used in the game is decided in data/calibration/variable_map.json, not here.

Names are matched to Kemendagri codes within the stated province; every non-trivial alias is listed
in ALIASES with a reason. Unmatched rows fail the run (no silent drops).
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import pdfplumber

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, sha256_file, utc_now  # noqa: E402

SOURCE_ID = "SRC-BNPB-IRBI-2024"
PDF = "data/raw/bnpb/irbi_2024/BUKU_IRBI_2024.pdf"
URL = "https://inarisk.bnpb.go.id/pdf/BUKU%20IRBI%202024.pdf"
REG = REPO_ROOT / "data/normalized/regions/region_registry.json"
ROW = re.compile(r"^(\d{1,3}) (.+?) ([\d.]+) (RENDAH|SEDANG|TINGGI)$", re.M)

PROVINCE_ALIASES = {  # IRBI spelling -> registry province code (only where names differ)
    "DKI JAKARTA": "31",
    "DI YOGYAKARTA": "34",
    "P A P U A": "91",  # PDF text layer letter-spaces this province name in some rows
}
# (province code, IRBI name) -> region_id. Each needs a reason.
ALIASES: dict[tuple[str, str], tuple[str, str]] = {
    ("31", "JAKARTA PUSAT"): ("31.71", "kota administrasi listed without 'KOTA' prefix"),
    ("31", "JAKARTA UTARA"): ("31.72", "kota administrasi listed without 'KOTA' prefix"),
    ("31", "JAKARTA BARAT"): ("31.73", "kota administrasi listed without 'KOTA' prefix"),
    ("31", "JAKARTA SELATAN"): ("31.74", "kota administrasi listed without 'KOTA' prefix"),
    ("31", "JAKARTA TIMUR"): ("31.75", "kota administrasi listed without 'KOTA' prefix"),
    ("76", "MAMUJU UTARA"): ("76.01", "former name of Kabupaten Pasangkayu (same Kemendagri code 76.01)"),
    ("81", "MALUKU TENGGARA BARAT"): ("81.03", "former name of Kabupaten Kepulauan Tanimbar (same code 81.03)"),
}


def norm(s: str) -> str:
    s = s.upper().replace("KABUPATEN ", "").replace("KOTA ADM. ", "KOTA ").replace("ADM. ", "")
    return re.sub(r"[^A-Z0-9]", "", s)


def load_registry():
    reg = json.loads(REG.read_text(encoding="utf-8"))
    provs = {}
    for p in reg["provinces"]:
        for n in {p["name"], p.get("name_big") or ""}:
            if n:
                provs[n.upper()] = p["region_id"]
    provs.update(PROVINCE_ALIASES)
    index: dict[tuple[str, str], str] = {}
    for r in reg["kabkota"]:
        kind_prefix = "KOTA" if r["kind"] == "kota" else ""
        for n in {r["name"], r["name_big"], r.get("name_kemendagri_secondary") or ""}:
            if not n:
                continue
            base = norm(re.sub(r"(?i)^(kota adm\.|kota|kabupaten administrasi|kabupaten)\s+", "", n))
            index[(r["parent_region_id"], kind_prefix + base)] = r["region_id"]
    return provs, index


def split_row(text: str, provs: dict) -> tuple[str, str]:
    for pname in sorted(provs, key=len, reverse=True):  # longest province suffix wins
        if text.endswith(" " + pname):
            return text[: -len(pname) - 1].strip(), provs[pname]
    raise ValueError(f"province not recognized in row: {text!r}")


def match(name: str, prov: str, index: dict) -> str:
    if (prov, name) in ALIASES:
        return ALIASES[(prov, name)][0]
    is_kota = name.startswith("KOTA ")
    base = norm(name[5:] if is_kota else name)
    key = (prov, ("KOTA" if is_kota else "") + base)
    if key in index:
        return index[key]
    raise KeyError(f"no registry match for {name!r} in province {prov}")


def parse_pages(pdf, first: int, last: int) -> list[tuple]:
    rows = []
    for i in range(first - 1, last):
        rows += ROW.findall(pdf.pages[i].extract_text() or "")
    return rows


def main() -> int:
    pdf_path = REPO_ROOT / PDF
    digest = sha256_file(pdf_path)
    manifest = {"source_id": SOURCE_ID, "url": URL, "retrieved_at": "2026-10-06",
                "files": {"BUKU_IRBI_2024.pdf": {"sha256": digest, "bytes": pdf_path.stat().st_size}},
                "note": "PDF gitignored (size); checksum here. Downloaded with resumable curl; verified %%EOF and 374 pages."}
    (pdf_path.parent / "MANIFEST.json").write_text(json.dumps(manifest, indent=1), encoding="utf-8")

    provs, index = load_registry()
    all_ids = {rid for (_p, _n), rid in index.items()}
    pdf = pdfplumber.open(pdf_path)
    # Locate tables by their headings instead of hardcoding page numbers.
    total_pages, flood_pages = [], []
    for i, p in enumerate(pdf.pages):
        t = p.extract_text() or ""
        if "INDEKS RISIKO BENCANA BANJIR TAHUN 2024" in t or (flood_pages and flood_pages[-1] == i and ROW.search(t) and "TAHUN 2024" not in t):
            flood_pages.append(i + 1)
        elif "SKOR" in t and "KELAS RISIKO" in t and not flood_pages and "PER ANCAMAN" not in t and ROW.search(t):
            total_pages.append(i + 1)
    rows_total = parse_pages(pdf, total_pages[0], total_pages[-1]) if total_pages else []
    rows_flood = parse_pages(pdf, flood_pages[0], flood_pages[-1]) if flood_pages else []

    now = utc_now()
    out: dict[str, list[dict]] = {"official_irbi_total_score": [], "official_irbi_flood_score": []}
    unmatched = []
    for var, rows, label in (("official_irbi_total_score", rows_total, "multi-ancaman"), ("official_irbi_flood_score", rows_flood, "banjir")):
        seen = set()
        for no, text, score, cls in rows:
            try:
                name, prov = split_row(text, provs)
                rid = match(name, prov, index)
            except (ValueError, KeyError) as e:
                unmatched.append(f"{var} #{no}: {e}")
                continue
            if rid in seen:
                unmatched.append(f"{var} #{no}: duplicate region {rid} ({text})")
                continue
            seen.add(rid)
            out[var].append({
                "obs_variable_id": var, "region_id": rid, "resolution": "kabkota", "value": float(score),
                "reference_period": "2024", "unit": "skor IRBI", "source_id": SOURCE_ID,
                "dataset_ref": f"bnpb:irbi2024:{label}:no={no}", "source_label": text,
                "retrieved_at": now, "raw_path": PDF, "fact_class": "REAL_OFFICIAL",
                "note": f"kelas risiko {cls}",
            })
        if var == "official_irbi_flood_score":
            for rid in sorted(all_ids - seen):
                out[var].append({
                    "obs_variable_id": var, "region_id": rid, "resolution": "kabkota", "value": None,
                    "missing_class": "NOT_PUBLISHED", "reference_period": "2024", "unit": "skor IRBI",
                    "source_id": SOURCE_ID, "dataset_ref": "bnpb:irbi2024:banjir:absent",
                    "retrieved_at": now, "raw_path": PDF, "fact_class": "REAL_OFFICIAL",
                    "note": "Not listed in the IRBI 2024 flood table; absence is not stated to mean zero risk.",
                })
    if unmatched:
        print("UNMATCHED / ERRORS:\n  " + "\n  ".join(unmatched))
        return 1
    for var, rows in out.items():
        observations.write(var, rows)
    fl = out["official_irbi_flood_score"]
    n_flood = sum(r.get("value") is not None for r in fl)
    print(f"official_irbi_total_score: {len(out['official_irbi_total_score'])} rows (pages {total_pages[0]}-{total_pages[-1]}); "
          f"official_irbi_flood_score: {n_flood} listed + {len(fl) - n_flood} NOT_PUBLISHED (pages {flood_pages[0]}-{flood_pages[-1]})")
    return 0 if len(out["official_irbi_total_score"]) == 514 else 1


if __name__ == "__main__":
    raise SystemExit(main())
