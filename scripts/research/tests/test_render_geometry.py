"""Tests for navigation groups, render LODs and the area-unit audit (docs/14 QA).

Run: python3 -m unittest discover -s scripts/research/tests
LOD tests are skipped (not failed) until the LODs have been built.
"""

from __future__ import annotations

import csv
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import DATA_RAW, REPO_ROOT  # noqa: E402
from geo import structural_problems  # noqa: E402

SNAP = "SNAP-2026-10-21"
GEO = REPO_ROOT / "data" / "normalized" / "geography"
RENDER = REPO_ROOT / "data" / "processed" / "geography" / SNAP / "render"
LODS = ("lod1", "lod2", "lod3")
REGISTRY = json.loads((GEO / "region_registry.json").read_text(encoding="utf-8"))
NAV = json.loads((REPO_ROOT / "data" / "design" / "navigation_groups.json").read_text(encoding="utf-8"))


class TestRawCaptureComplete(unittest.TestCase):
    """Required: never skipped. Fails if the capture report is missing."""

    def test_all_541_features_captured_with_integrity(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "geometry_capture_check.json").read_text())
        self.assertEqual(rep["features_expected"], 541)
        self.assertEqual(rep["features_captured"], 541)
        self.assertEqual(rep["page_integrity_problems"], [])
        self.assertEqual(rep["duplicate_objectids"], [])
        self.assertEqual(rep["empty_geometry_objectids"], [])
        self.assertEqual(rep["registry_regions_affected"], [])

    def test_only_declared_recovery_copy_is_not_full_resolution(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "geometry_capture_check.json").read_text())
        self.assertEqual([r["OBJECTID"] for r in rep["recovered_features_not_full_resolution"]], [3424])
        self.assertIn("maxAllowableOffset=0.0000001", rep["recovered_features_not_full_resolution"][0]["url"])
        files = sorted(p.name for p in (DATA_RAW / "SRC-0001" / SNAP).glob("kabkota_geom_*oid*.geojson"))
        self.assertEqual(files, ["kabkota_geom_oid03424_mao1e-7.geojson"])


class TestNavigationGroups(unittest.TestCase):
    def test_seven_groups_with_stable_keys(self):
        keys = [g["group_key"] for g in NAV["groups"]]
        self.assertEqual(keys, ["sumatera", "jawa", "bali_nusa_tenggara", "kalimantan", "sulawesi", "maluku", "papua"])
        self.assertTrue(all(g["display_name"] for g in NAV["groups"]))

    def test_every_province_in_exactly_one_group(self):
        members = [p for g in NAV["groups"] for p in g["provinces"]]
        self.assertEqual(len(members), 38)
        self.assertEqual(len(set(members)), 38)
        self.assertEqual(set(members), {p["region_id"] for p in REGISTRY["provinces"]})

    def test_group_sizes(self):
        sizes = {g["group_key"]: len(g["provinces"]) for g in NAV["groups"]}
        self.assertEqual(sizes, {"sumatera": 10, "jawa": 6, "bali_nusa_tenggara": 3, "kalimantan": 5,
                                 "sulawesi": 6, "maluku": 2, "papua": 6})
        self.assertEqual(sum(sizes.values()), 38)

    def test_presentation_only(self):
        self.assertTrue(NAV["presentation_only"])
        # the taxonomy must not leak into the official registry
        self.assertNotIn("nav_group_key", REGISTRY["regions"][0])


class TestLodsBuiltRequired(unittest.TestCase):
    """Required: FAILS (never skips) if a production LOD file is missing, so a missing build
    cannot hide behind TestRenderLods' skip."""

    def test_production_lod_files_exist(self):
        for lod in LODS:
            for name in ("kabkota.json", "provinsi.json", "fragments.json", "build_log.json"):
                self.assertTrue((RENDER / lod / name).exists(), f"{lod}/{name} missing")


class TestRenderLods(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lods = {}
        for lod in LODS:
            d = RENDER / lod
            if (d / "kabkota.json").exists():
                cls.lods[lod] = {n: json.loads((d / f"{n}.json").read_text())["features"]
                                 for n in ("kabkota", "provinsi", "fragments")}
        if not cls.lods:
            raise unittest.SkipTest("render LODs not built yet")

    def test_all_three_lods_present(self):
        self.assertEqual(set(self.lods), set(LODS))

    def test_counts(self):
        for lod, layers in self.lods.items():
            self.assertEqual(len(layers["kabkota"]), 514, lod)
            self.assertEqual(len(layers["provinsi"]), 38, lod)
            self.assertEqual(len(layers["fragments"]), 21, lod)

    def test_ids_codes_and_parents_preserved(self):
        reg = {r["region_id"]: r for r in REGISTRY["regions"]}
        for lod, layers in self.lods.items():
            seen = set()
            for f in layers["kabkota"]:
                p = f["properties"]
                r = reg[p["region_id"]]
                self.assertEqual(p["kode_bps"], r["kode_bps"], (lod, p["region_id"]))
                self.assertEqual(p["parent_region_id"], r["parent_region_id"], (lod, p["region_id"]))
                self.assertEqual(p["region_level"], r["region_level"], (lod, p["region_id"]))
                seen.add(p["region_id"])
            self.assertEqual(seen, set(reg), lod)

    def test_identical_id_sets_across_lods(self):
        sets = {lod: sorted(f["properties"]["region_id"] for f in l["kabkota"]) for lod, l in self.lods.items()}
        self.assertEqual(len({json.dumps(v) for v in sets.values()}), 1)

    def test_structurally_valid(self):
        for lod, layers in self.lods.items():
            for name, feats in layers.items():
                for f in feats:
                    self.assertEqual(structural_problems(f["geometry"]), [], (lod, name, f["properties"]))

    def test_validation_report_hard_checks_pass(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "render_geometry_validation.json").read_text())
        for lod in LODS:
            failed = [c["check"] for c in rep["lods"][lod]["checks"] if c["hard"] and not c["passed"]]
            self.assertEqual(failed, [], lod)

    def test_island_audit_no_loss(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "island_component_audit.json").read_text())
        for lod in LODS:
            l = rep["lods"][lod]
            self.assertEqual(l["regions_with_any_part"], 514, lod)
            self.assertNotIn("lost", l["status_counts"], lod)
            self.assertEqual(l["noticeable_parts_displaced_or_lost"], [], lod)

    def test_precision_and_method_consistent(self):
        # build command, build log, output coordinates and DECISIONS.md D-015 must agree
        sel = json.loads((REPO_ROOT / "research" / "reports" / "lod_tolerance_selection.json").read_text())
        decisions = (REPO_ROOT / "DECISIONS.md").read_text(encoding="utf-8")
        self.assertIn("1e-6°", decisions)
        for lod in LODS:
            log = json.loads((RENDER / lod / "build_log.json").read_text())
            self.assertEqual(log["precision_deg"], 1e-6, lod)
            self.assertIn("precision=1e-06", " ".join(log["command_pass_b"]).replace("0.000001", "1e-06"), lod)
            self.assertEqual(log["simplify_method"], "dp", lod)
            self.assertEqual(log["interval_m"], sel["selected_interval_m"][lod], lod)
            for f in self.lods[lod]["kabkota"][:50]:
                for poly in (f["geometry"]["coordinates"] if f["geometry"]["type"] == "MultiPolygon"
                             else [f["geometry"]["coordinates"]]):
                    for c in poly[0][:200]:
                        for v in c:
                            self.assertAlmostEqual(v, round(v, 6), places=9, msg=(lod, v))

    def test_province_crosscheck_present(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "province_outline_crosscheck.json").read_text())
        self.assertTrue(rep["lod_dir"].endswith("lod3"))
        inter = rep["inter_province_vs_province_outlines"]
        self.assertGreater(inter["n"], 10_000)
        # LOD3 tolerance is 40 m; the official lines are an older edition (<= 2024-09)
        self.assertGreaterEqual(inter["within_50m_pct"], 99.0)
        self.assertGreaterEqual(inter["side_match_pct"], 99.0)
        self.assertEqual(rep["unmatched_province_names_in_lines"], {})

    def test_lods_strictly_coarser(self):
        rep = json.loads((REPO_ROOT / "research" / "reports" / "render_geometry_validation.json").read_text())
        v = [rep["lods"][lod]["vertices"]["kabkota"] for lod in LODS]
        self.assertLess(v[0], v[1])
        self.assertLess(v[1], v[2])
        self.assertLess(v[2], rep["raw_source"]["kabkota_vertices"])


class TestNoSilentAreaConversion(unittest.TestCase):
    def test_registry_luaswh_equals_raw_value(self):
        attrs = {f["attributes"]["OBJECTID"]: f["attributes"] for f in json.loads(
            (DATA_RAW / "SRC-0001" / SNAP / "kabkota_attributes.json").read_text())["features"]}
        for r in REGISTRY["regions"]:
            main = int(r["big_objectids"].split(";")[0])
            self.assertEqual(float(r["big_luaswh_raw"]), attrs[main]["LUASWH"], r["region_id"])

    def test_audit_keeps_original_and_derived_separate(self):
        path = REPO_ROOT / "data" / "processed" / "geography" / SNAP / "area_unit_audit.csv"
        if not path.exists():
            self.skipTest("area audit not run yet")
        with path.open(encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        self.assertEqual(len(rows), 514)
        reg = {r["region_id"]: r for r in REGISTRY["regions"]}
        for row in rows:
            self.assertEqual(row["luaswh_raw"], str(reg[row["region_id"]]["big_luaswh_raw"]))
            self.assertEqual(row["luaswh_declared_unit"], "HA")
            self.assertEqual(row["luaswh_source_label"], "Luas Wilayah Menurut Peraturan (HA)")
            # the evidenced interpretation is separate metadata, never a rewrite of the source fields
            self.assertEqual(row["luaswh_evidenced_unit"], "km2")
            self.assertEqual(row["luaswh_unit_status"], "UNIT_KM2_EVIDENCED")
        # derived area lives in its own column, never in a field that looks like the source
        self.assertIn("geom_area_km2", rows[0])
        self.assertNotIn("luaswh_km2", rows[0])
        self.assertNotIn("luaswh_ha", rows[0])

    def test_render_layers_carry_no_area_fields(self):
        p = RENDER / "lod1" / "kabkota.json"
        if not p.exists():
            self.skipTest("render LODs not built yet")
        props = json.loads(p.read_text())["features"][0]["properties"]
        self.assertFalse({k for k in props if "luas" in k.lower() or "area" in k.lower()})


if __name__ == "__main__":
    unittest.main()
