"""Ingest official BPS dynamic tables from their public web pages (no API key needed).

BPS statistics-table pages (www.bps.go.id/id/statistics-table/2/...) embed the table's complete data
cube as JSON in the page (keys `vervar`, `var`, `turvar`, `tahun`, `turtahun`, `datacontent`). This
script fetches each page once (cached raw capture + sha256 sidecar), decodes the cube, maps BPS
region codes to canonical Kemendagri ids via the registry crosswalk (kode_bps), and writes REAL
observations. Values are copied exactly as published; nothing is imputed. BPS rows absent from the
registry (e.g. pre-2022 Papua codes kept for history) are ignored and counted in the report.

Cell key = <vervar><var><turvar><tahun><turtahun>, e.g. "3173" + "413" + "0" + "124" + "0".
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, fetch_to_file, log_access, sha256_file, utc_now  # noqa: E402

RAW_DIR = REPO_ROOT / "data/raw/bps/tables"
REGISTRY = REPO_ROOT / "data/normalized/regions/region_registry.json"
SNAPSHOT_ID = "BPS-TABLES-2026-10-23"

# obs_variable_id -> table page, the turvar to read (None = the table has none) and unit.
TABLES = {
    "pop_total": {
        "source_id": "SRC-BPS-TBL-2790-PENDUDUK-KABKOTA",
        "url": "https://www.bps.go.id/id/statistics-table/2/Mjc5MCMy/-jumlah-penduduk-menurut-kabupaten-kota-dan-kelompok-umur.html",
        "raw": "bps_tbl2790_penduduk_kabkota_kelompok_umur.html",
        "turvar_label": "TOTAL",
        "unit": "jiwa",
        "additive": True,  # province rows must equal the sum of their kab/kota
        "note": "Hasil Proyeksi Penduduk Indonesia hasil Sensus Penduduk 2020 (BPS).",
    },
    "ipm": {
        "source_id": "SRC-BPS-TBL-413-IPM",
        "url": "https://www.bps.go.id/id/statistics-table/2/NDEzIzI=/-metode-baru-indeks-pembangunan-manusia.html",
        "raw": "bps_tbl413_ipm_metode_baru.html",
        "turvar_label": None,
        "unit": "indeks (0-100)",
        "note": "Indeks Pembangunan Manusia metode baru (BPS).",
    },
}


def _cube(html: str) -> dict:
    s = html.replace('\\"', '"').replace("\\\\", "\\")

    def grab(key: str):
        i = s.find(f'"{key}":')
        if i < 0:
            raise ValueError(f"key {key!r} not found in page")
        j = i + len(key) + 3
        opener = s[j]
        closer = {"[": "]", "{": "}"}.get(opener)
        if closer is None:
            m = re.match(r'"((?:[^"\\]|\\.)*)"', s[j:])
            return m.group(1) if m else None
        depth = 0
        for k in range(j, len(s)):
            if s[k] == opener:
                depth += 1
            elif s[k] == closer:
                depth -= 1
                if depth == 0:
                    return json.loads(s[j:k + 1])
        raise ValueError(f"unterminated {key}")

    return {k: grab(k) for k in ("vervar", "var", "turvar", "tahun", "turtahun", "datacontent", "last_update")}


def ingest(obs_id: str, spec: dict, registry: dict) -> dict:
    raw = RAW_DIR / spec["raw"]
    fetch_to_file(spec["url"], raw, spec["source_id"])
    sha = sha256_file(raw)
    meta_path = raw.with_name(raw.name + ".meta.json")
    if not meta_path.exists():
        meta_path.write_text(json.dumps({"source_id": spec["source_id"], "snapshot_id": SNAPSHOT_ID, "url": spec["url"],
                                         "retrieved_at": utc_now(), "http_status": 200, "bytes": raw.stat().st_size,
                                         "sha256": sha}, indent=1) + "\n", encoding="utf-8")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    if meta["sha256"] != sha:
        raise RuntimeError(f"raw capture changed on disk: {raw}")
    cube = _cube(raw.read_text(encoding="utf-8"))
    var = cube["var"][0]
    turvar = "0"
    if spec["turvar_label"]:
        turvar = str(next(t["val"] for t in cube["turvar"] if t["label"].strip().upper() == spec["turvar_label"]))
    tahun = max(cube["tahun"], key=lambda t: int(t["label"]))
    turtahun = str(cube["turtahun"][0]["val"]) if cube.get("turtahun") else "0"
    dc = cube["datacontent"]
    kab = {r["kode_bps"]: r for r in registry["regencies"]}
    prov = {p["kode_bps"]: p for p in registry["provinces"]}
    rows, unmatched = [], []
    for vv in cube["vervar"]:
        code = str(vv["val"])
        key = f"{code}{var['val']}{turvar}{tahun['val']}{turtahun}"
        if key not in dc:
            continue
        target = kab.get(code) or (prov.get(code[:2]) if code.endswith("00") else None)  # BPS province rows: "1100"
        if target is None:
            unmatched.append(code)
            continue
        rows.append({
            "obs_variable_id": obs_id, "region_id": target["region_id"],
            "resolution": "kabkota" if code in kab else "provinsi",
            "reference_period": str(tahun["label"]), "unit": spec["unit"], "value": float(dc[key]),
            "source_id": spec["source_id"], "dataset_ref": f"bps:var={var['val']};vervar={code};th={tahun['val']}",
            "retrieved_at": meta["retrieved_at"], "raw_path": str(raw.relative_to(REPO_ROOT)),
            "fact_class": "REAL_OFFICIAL", "source_label": re.sub("<[^>]+>", "", vv["label"]).strip(),
            "note": f"{spec['note']} Tabel diperbarui BPS {cube['last_update']}.",
        })
    conflicts = []
    if spec.get("additive"):
        # A province row that disagrees with its kab/kota sum (e.g. a pre-2022-split Papua total next to
        # post-split regencies) is dropped and reported, never silently kept.
        sums: dict[str, float] = {}
        for r in rows:
            if r["resolution"] == "kabkota":
                sums[r["region_id"][:2]] = sums.get(r["region_id"][:2], 0.0) + r["value"]
        for r in [r for r in rows if r["resolution"] == "provinsi"]:
            s = sums.get(r["region_id"], 0.0)
            if abs(r["value"] - s) > 0.005 * max(s, 1.0):
                conflicts.append({"region_id": r["region_id"], "published": r["value"], "sum_kabkota": s})
                rows.remove(r)
        for c in conflicts:
            log_access(spec["source_id"], spec["url"], "conflict",
                       f"province {c['region_id']} total {c['published']:.0f} != kab/kota sum {c['sum_kabkota']:.0f}; province row dropped")
    observations.write(obs_id, rows)
    n_kab = sum(r["resolution"] == "kabkota" for r in rows)
    log_access(spec["source_id"], spec["url"], "ok", f"parsed {n_kab} kab/kota + {len(rows) - n_kab} provinsi, period {tahun['label']}")
    return {"obs": obs_id, "period": tahun["label"], "kabkota": n_kab, "provinsi": len(rows) - n_kab,
            "unmatched_bps_codes": len(unmatched), "conflicting_province_rows": conflicts, "last_update": cube["last_update"], "sha256": sha}


def main() -> int:
    reg = json.loads(REGISTRY.read_text(encoding="utf-8"))
    registry = {"regencies": [r for r in reg["kabkota"] if r.get("kode_bps")],
                "provinces": [{"region_id": p["region_id"], "kode_bps": p["kode_bps"]} for p in reg["provinces"] if p.get("kode_bps")]}
    for obs_id, spec in TABLES.items():
        print(json.dumps(ingest(obs_id, spec, registry)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
