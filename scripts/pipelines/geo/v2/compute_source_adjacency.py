"""Neighbour pairs of the raw full-resolution BIG polygons (reference for topology checks).

Two features are neighbours when they share a vertex after quantizing coordinates to
1e-6 deg, the same grid as the render LODs (geo.vertex_adjacency), so source and LOD
adjacency are measured identically.

52 M raw vertices do not fit comfortably in Python dicts at once, so one parse pass
spills compact (vertex key, feature index) records into per-longitude-band temp files,
then each band is processed on its own.

Feature ids: kab/kota polygons -> region_id (incl. 'Wilayah terapung' parts);
TIPADM=6 fragments -> 'F<OBJECTID>'.
Output: data/processed/geography/<snap>/fullres_adjacency.json (keyed by raw page sha256)
"""

from __future__ import annotations

import argparse
import json
import math
import tempfile
from array import array
from pathlib import Path

from common import DATA_NORMALIZED, DATA_RAW, REPO_ROOT, utc_now_iso
from geo import polygons_of

QUANTUM_INV = 1_000_000  # 1e-6 deg
LON0, LON1, BAND = 94.0, 142.0, 3.0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    args = ap.parse_args()
    raw = DATA_RAW / "SRC-0001" / args.snapshot
    pages = sorted(raw.glob("kabkota_geom_*.geojson"))
    key = [json.loads(Path(str(p) + ".meta.json").read_text())["sha256"] for p in pages]
    out = REPO_ROOT / "data" / "processed" / "geography" / args.snapshot / "fullres_adjacency.json"
    if out.exists() and json.loads(out.read_text()).get("raw_page_sha256") == key:
        print("cached")
        return

    registry = json.loads((DATA_NORMALIZED / "geography" / "region_registry.json").read_text(encoding="utf-8"))
    oid_to_id = {int(o): r["region_id"] for r in registry["regions"] for o in r["big_objectids"].split(";")}
    ids: list[str] = []
    index: dict[str, int] = {}
    nbands = math.ceil((LON1 - LON0) / BAND)

    with tempfile.TemporaryDirectory() as tmp:
        files = [open(Path(tmp) / f"band{b}.bin", "wb") for b in range(nbands)]
        fid_files = [open(Path(tmp) / f"band{b}.fid", "wb") for b in range(nbands)]
        for page in pages:
            for f in json.loads(page.read_text())["features"]:
                oid = f["properties"]["OBJECTID"]
                fid = oid_to_id.get(oid, f"F{oid}")
                if fid not in index:
                    index[fid] = len(ids)
                    ids.append(fid)
                fi = index[fid]
                keys = [array("q") for _ in range(nbands)]
                for poly in polygons_of(f["geometry"]):
                    for ring in poly:
                        for c in ring:
                            qx, qy = round(c[0] * QUANTUM_INV), round((c[1] + 20) * QUANTUM_INV)
                            b = min(nbands - 1, max(0, int((c[0] - LON0) // BAND)))
                            keys[b].append(qx * 100_000_000 + qy)
                for b, k in enumerate(keys):
                    if k:
                        k.tofile(files[b])
                        array("h", [fi]).tofile(fid_files[b])
                        array("q", [len(k)]).tofile(fid_files[b])
            print(f"spilled {page.name}")
        for fh in files + fid_files:
            fh.close()

        pairs = set()
        for b in range(nbands):
            kp, fp = Path(tmp) / f"band{b}.bin", Path(tmp) / f"band{b}.fid"
            if kp.stat().st_size == 0:
                continue
            keys = array("q")
            keys.frombytes(kp.read_bytes())
            meta = fp.read_bytes()
            # first owner per vertex in a compact dict; every further distinct owner in
            # `extra`, so junctions of 3+ features yield all their pairs (not just first-vs-rest)
            owner: dict[int, int] = {}
            extra: dict[int, set[int]] = {}
            pos, off = 0, 0
            while off < len(meta):
                fi = array("h", meta[off:off + 2])[0]
                n = array("q", meta[off + 2:off + 10])[0]
                off += 10
                for k in keys[pos:pos + n]:
                    o = owner.setdefault(k, fi)
                    if o != fi:
                        extra.setdefault(k, {o}).add(fi)
                pos += n
            for fis in extra.values():
                fl = sorted(ids[i] for i in fis)
                pairs.update((a, c) for i, a in enumerate(fl) for c in fl[i + 1:])
            print(f"band {b}: {len(keys)} vertices, pairs so far {len(pairs)}")

    doc = {"snapshot_id": args.snapshot, "built_at": utc_now_iso(), "raw_page_sha256": key,
           "quantum_deg": 1 / QUANTUM_INV, "features": len(ids),
           "pairs": sorted(list(p) for p in pairs)}
    out.write_text(json.dumps(doc) + "\n")
    print(f"{len(pairs)} neighbour pairs -> {out.relative_to(REPO_ROOT)}")


if __name__ == "__main__":
    main()
