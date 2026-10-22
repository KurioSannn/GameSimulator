"""BIG `luaswh` -> observation `area_km2` (REAL_OFFICIAL, kab/kota, edition 2023-09).

Kab/kota spanning several BIG feature rows are summed (same code). Unit: km² is inferred
(G-03, see the check below) and kept flagged in the note until BIG's field definition is archived.
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT  # noqa: E402

RAW = "data/raw/big/kabkota_2023-09/attributes.json"
CODE_RE = re.compile(r"^\d\d\.\d\d$")


def main() -> int:
    raw = json.loads((REPO_ROOT / RAW).read_text(encoding="utf-8"))
    manifest = json.loads((REPO_ROOT / "data/raw/big/kabkota_2023-09/MANIFEST.json").read_text(encoding="utf-8"))
    sums: dict[str, float] = defaultdict(float)
    labels: dict[str, str] = {}
    for f in raw["features"]:
        a = f["attributes"]
        code = (a.get("kdpkab") or "").strip()
        if CODE_RE.match(code) and a.get("luaswh") is not None:
            sums[code] += float(a["luaswh"])
            labels[code] = a["namobj"]
    rows = [{
        "obs_variable_id": "area_km2", "region_id": code, "resolution": "kabkota", "value": round(v, 6),
        "reference_period": "2023-09", "unit": "km2", "source_id": "SRC-BIG-ADM-KABKOTA",
        "dataset_ref": "big:Wilayah_Administrasi_Kabupaten__Kota/FeatureServer/0:luaswh",
        "source_label": labels[code], "retrieved_at": manifest["retrieved_at"], "raw_path": RAW,
        "fact_class": "REAL_OFFICIAL",
        "note": "Unit km2 inferred (G-03): DKI Jakarta sum ~661 km2 matches its published land area order of magnitude; verify against BIG field definition.",
    } for code, v in sorted(sums.items())]
    path = observations.write("area_km2", rows)
    dki = sum(r["value"] for r in rows if r["region_id"].startswith("31."))
    print(f"wrote {len(rows)} rows -> {path.relative_to(REPO_ROOT)}; DKI sum = {dki:.1f} km2")
    return 0 if len(rows) == 514 else 1


if __name__ == "__main__":
    raise SystemExit(main())
