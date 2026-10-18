"""Capture the BPS <-> Kemendagri region-code crosswalk (SRC-0002).

Source: BPS Sistem Informasi Geografis, "Bridging Kode Wilayah"
  https://sig.bps.go.id/bridging-kode   (robots.txt: Disallow: <empty>)

Captures province and kabupaten/kota levels for one bridging period.
Kecamatan/desa levels are intentionally out of scope for this milestone
(the simulation's region unit is kabupaten/kota; see docs/07).

Usage:
  python3 scripts/research/fetch_bps_bridging.py [--period 2025_2.2025]
"""

from __future__ import annotations

import argparse
import json

from common import fetch_raw, json_validate

SOURCE_ID = "SRC-0002"
BASE = "https://sig.bps.go.id"
DEFAULT_PERIOD = "2025_2.2025"  # BPS 2025 Semester 2 <-> Kemendagri 2025 (latest listed 2026-10-21)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--period", default=DEFAULT_PERIOD)
    args = ap.parse_args()

    fetch_raw(SOURCE_ID, args.snapshot, "periods.json",
              f"{BASE}/rest-drop-down/getperiode", validate=json_validate)

    prov_path = fetch_raw(
        SOURCE_ID, args.snapshot, f"bridging_provinsi_{args.period}.json",
        f"{BASE}/rest-bridging/getwilayah?level=provinsi&parent=0&periode_merge={args.period}",
        validate=json_validate)
    provinces = json.loads(prov_path.read_text(encoding="utf-8"))
    print(f"provinces: {len(provinces)}")

    total = 0
    for p in provinces:
        path = fetch_raw(
            SOURCE_ID, args.snapshot, f"bridging_kabupaten_{args.period}_{p['kode_bps']}.json",
            f"{BASE}/rest-bridging/getwilayah?level=kabupaten&parent={p['kode_bps']}"
            f"&periode_merge={args.period}",
            validate=json_validate)
        n = len(json.loads(path.read_text(encoding="utf-8")))
        total += n
        print(f"  {p['kode_bps']} {p['nama_bps']}: {n}")
    print(f"kabupaten/kota rows: {total}")


if __name__ == "__main__":
    main()
