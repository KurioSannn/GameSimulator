"""Measure file size and JSON read+parse time for each render LOD file.

PROXY MEASUREMENT: Godot is not installed on the research machine, so in-engine load
time is NOT measured here. Node (V8 JSON.parse) and CPython json.loads timings are
reported as a lower-bound proxy for parsing cost; Godot's JSON parser and the
conversion to Polygon2D/PackedVector2Array will add time. Re-measure in Godot.

Output: research/reports/lod_load_times.json
"""

from __future__ import annotations

import json
import platform
import statistics
import subprocess
import time

from common import REPO_ROOT, utc_now_iso

SNAP = "SNAP-2026-10-21"
RUNS = 5
NODE_SNIPPET = """
const fs=require('fs');const f=process.argv[1];const n=+process.argv[2];const t=[];
for(let i=0;i<n;i++){const s=process.hrtime.bigint();JSON.parse(fs.readFileSync(f,'utf8'));
t.push(Number(process.hrtime.bigint()-s)/1e6);}console.log(JSON.stringify(t));
"""


def main() -> None:
    render = REPO_ROOT / "data" / "processed" / "geography" / SNAP / "render"
    results = {}
    for lod_dir in sorted(p for p in render.iterdir() if p.is_dir() and p.name.startswith("lod")):
        for f in sorted(lod_dir.glob("*.json")):
            if f.name == "build_log.json":
                continue
            py = []
            for _ in range(RUNS):
                t0 = time.perf_counter()
                json.loads(f.read_text(encoding="utf-8"))
                py.append((time.perf_counter() - t0) * 1000)
            node = json.loads(subprocess.run(["node", "-e", NODE_SNIPPET, str(f), str(RUNS)],
                                             capture_output=True, text=True, check=True).stdout)
            results[f"{lod_dir.name}/{f.name}"] = {
                "bytes": f.stat().st_size,
                "node_parse_ms_median": statistics.median(node),
                "python_parse_ms_median": statistics.median(py),
            }
            print(f"{lod_dir.name}/{f.name}: {f.stat().st_size/1e6:.2f} MB  node {statistics.median(node):.1f} ms  "
                  f"python {statistics.median(py):.1f} ms")
    report = {"measured_at": utc_now_iso(), "runs_per_file": RUNS, "kind": "PROXY (not Godot)",
              "machine": {"platform": platform.platform(), "machine": platform.machine(),
                          "node": subprocess.run(["node", "--version"], capture_output=True, text=True).stdout.strip(),
                          "python": platform.python_version()},
              "files": results}
    (REPO_ROOT / "research" / "reports" / "lod_load_times.json").write_text(
        json.dumps(report, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
