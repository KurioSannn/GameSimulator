"""Game map meshes (game/data/map/v2) stay consistent with the validated geography v2 LODs.

Fails when the render LODs or the game registry change without rebuilding the meshes
(scripts/pipelines/game/build_map_lods.py), when a mesh file is modified, or when the projection or
the region order drifts.
"""
from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.fetch import REPO_ROOT, sha256_file  # noqa: E402

MAP = REPO_ROOT / "game/data/map/v2"
LODS = ("lod1", "lod2", "lod3")


class TestMapMeshes(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta = {lod: json.loads((MAP / f"kabkota_{lod}.json").read_text(encoding="utf-8")) for lod in LODS}
        cls.order = [r["region_id"] for r in json.loads((REPO_ROOT / "game/data/regions.json").read_text(encoding="utf-8"))["regions"]]

    def test_meshes_built_from_current_validated_render_lods(self):
        for lod, m in self.meta.items():
            src = REPO_ROOT / m["source"]["render_dir"]
            for name, digest in m["source"]["sha256"].items():
                self.assertEqual(sha256_file(src / name), digest, f"{lod}: {name} changed; rebuild the map meshes")

    def test_binary_matches_its_metadata(self):
        for lod, m in self.meta.items():
            path = MAP / m["bin"]["file"]
            self.assertEqual(path.stat().st_size, m["bin"]["bytes"], lod)
            self.assertEqual(sha256_file(path), m["bin"]["sha256"], lod)
            end = max(s["offset"] + s["bytes"] for s in m["bin"]["sections"].values())
            self.assertEqual(end, m["bin"]["bytes"], f"{lod}: sections cover the whole file")

    def test_region_order_identity_and_counts(self):
        for lod, m in self.meta.items():
            kab = [r for r in m["regions"] if r["kind"] == "kabkota"]
            frag = [r for r in m["regions"] if r["kind"] == "fragment"]
            self.assertEqual([r["id"] for r in kab], self.order, f"{lod}: entry i == registry region i")
            self.assertEqual(len(frag), 21, lod)
            self.assertEqual(m["counts"]["regions"], 514, lod)

    def test_triangulation_checked_and_exact(self):
        for lod, m in self.meta.items():
            self.assertLessEqual(m["triangulation"]["max_deviation"], m["triangulation"]["limit"], lod)
            self.assertEqual(m["triangulation"]["tool"], "earcut 3.2.3", lod)

    def test_same_projection_for_every_lod(self):
        proj = {json.dumps(m["projection"], sort_keys=True) for m in self.meta.values()}
        self.assertEqual(len(proj), 1)
        p = next(iter(self.meta.values()))["projection"]
        self.assertEqual((p["lon0"], p["lat0_standard_parallel"], p["units_per_degree"], p["y_down"]), (118.0, -2.5, 100.0, True))
        self.assertAlmostEqual(p["km_per_unit"], 2 * math.pi * 6371.0 / 360.0 / 100.0, places=12)

    def test_lod_view_bands_match_the_selection_record(self):
        sel = json.loads((REPO_ROOT / "research/reports/lod_tolerance_selection.json").read_text(encoding="utf-8"))
        for lod, m in self.meta.items():
            self.assertEqual(m["interval_m"], sel["selected_interval_m"][lod], lod)
        self.assertEqual(self.meta["lod1"]["view_width_km"], [2000, None])
        self.assertEqual(self.meta["lod2"]["view_width_km"], [300, 2000])
        self.assertEqual(self.meta["lod3"]["view_width_km"], [None, 300])
        self.assertEqual(sel["viewport_assumption_px"], 1600)


if __name__ == "__main__":
    unittest.main()
