"""Render PNG previews of each LOD for visual inspection (national / provincial / kab-kota zoom).

Each window draws the LOD's kab/kota fill + borders, and in red the raw source outline
clipped to the same window, so simplification error is visible. The red overlay is the raw
source simplified (Douglas-Peucker) to a quarter of a preview pixel - visually identical to
full resolution at that scale; drawing millions of raw vertices made Quick Look hang.
SVG is written by mapshaper; PNG is rasterised with macOS Quick Look (qlmanage).

Output: research/reports/geometry_previews/<window>__<lod>.png
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import tempfile
from pathlib import Path

from common import DATA_RAW, REPO_ROOT

MAPSHAPER = REPO_ROOT / "tools" / "geo" / "node_modules" / "mapshaper" / "bin" / "mapshaper"

# name: (bbox lon/lat, which LODs to draw, overlay raw source?)
WINDOWS = {
    "national_indonesia":      ((94.5, -11.5, 141.5, 6.5), ["lod1", "lod2"], False),
    "provincial_jatim_bali":   ((110.8, -9.0, 116.0, -6.6), ["lod1", "lod2", "lod3"], True),
    "provincial_maluku_utara": ((124.0, -2.6, 129.8, 2.8), ["lod1", "lod2", "lod3"], True),
    "kabkota_surabaya":        ((112.55, -7.42, 112.90, -7.12), ["lod2", "lod3"], True),
    "kabkota_kep_seribu":      ((106.35, -6.05, 106.85, -5.15), ["lod2", "lod3"], True),
    "kabkota_raja_ampat":      ((129.6, -2.4, 131.4, -0.2), ["lod2", "lod3"], True),
}


def run(cmd, timeout=900):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise SystemExit(r.stdout + r.stderr)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="SNAP-2026-10-21")
    ap.add_argument("--width", type=int, default=1400)
    args = ap.parse_args()
    render = REPO_ROOT / "data" / "processed" / "geography" / args.snapshot / "render"
    pages = sorted(str(p) for p in (DATA_RAW / "SRC-0001" / args.snapshot).glob("kabkota_geom_*.geojson"))
    out_dir = REPO_ROOT / "research" / "reports" / "geometry_previews"
    out_dir.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for name, (bbox, lods, overlay) in WINDOWS.items():
            # Quick Look renders square thumbnails and crops wider/taller SVGs, so every window
            # is expanded to a square (in degrees; Mercator stretch is <= 2 % at Indonesian
            # latitudes) and an invisible square frame layer fixes the SVG extent.
            cx, cy = (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2
            half = max(bbox[2] - bbox[0], bbox[3] - bbox[1]) / 2
            bbox = (cx - half, cy - half, cx + half, cy + half)
            bb = ",".join(f"{v:.6f}" for v in bbox)
            raw_clip = None
            if overlay:
                raw_clip = tmp / f"{name}_raw.json"
                # quarter-pixel tolerance for this window (metres per preview pixel / 4)
                quarter_px_m = (bbox[2] - bbox[0]) * 111_320 / args.width / 4
                run(["node", "--max-old-space-size=12288", str(MAPSHAPER), "-i", *pages, "combine-files",
                     "-merge-layers", "force", "-clip", f"bbox={bb}",
                     "-simplify", "dp", f"interval={quarter_px_m:.1f}m", "keep-shapes",
                     "-o", str(raw_clip), "format=geojson"])
            for lod in lods:
                svg = tmp / f"{name}__{lod}.svg"
                cmd = ["node", "--max-old-space-size=8192", str(MAPSHAPER),
                       "-i", str(render / lod / "kabkota.json"), "name=lod",
                       "-clip", f"bbox={bb}",
                       "-style", "fill='#dbe7f3'", "stroke='#34495e'", "stroke-width=0.6"]
                if raw_clip:
                    cmd += ["-i", str(raw_clip), "name=raw",
                            "-style", "fill=none", "stroke='#d0021b'", "stroke-width=0.35", "target=raw"]
                cmd += ["-rectangle", f"bbox={bb}", "name=frame",
                        "-style", "fill=none", "stroke=none", "target=frame",
                        "-proj", "merc", "target=*",
                        "-o", str(svg), f"width={args.width}",
                        "target=" + ("frame,lod,raw" if raw_clip else "frame,lod")]
                run(cmd)
                run(["qlmanage", "-t", "-s", str(args.width), "-o", str(tmp), str(svg)], timeout=180)
                shutil.move(str(tmp / f"{svg.name}.png"), out_dir / f"{name}__{lod}.png")
                print(f"{name}__{lod}.png")


if __name__ == "__main__":
    main()
