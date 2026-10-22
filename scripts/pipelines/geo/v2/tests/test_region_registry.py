"""Regression tests for the normalized region registry (docs/14 QA: geography registry, region count and IDs).

Run: python3 -m unittest discover -s scripts/pipelines/geo/v2/tests
"""

from __future__ import annotations

import csv
import json
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from build_region_registry import normalize_dagri_kab_code  # noqa: E402
from common import REPO_ROOT, sha256_file  # noqa: E402

GEO = REPO_ROOT / "data" / "normalized" / "geography"


def read_csv(name):
    with (GEO / name).open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


class TestCodeNormalization(unittest.TestCase):
    def test_trailing_zero_restored(self):
        self.assertEqual(normalize_dagri_kab_code("11.1"), "11.10")
        self.assertEqual(normalize_dagri_kab_code("91.2"), "91.20")

    def test_well_formed_codes_untouched(self):
        self.assertEqual(normalize_dagri_kab_code("11.01"), "11.01")
        self.assertEqual(normalize_dagri_kab_code("64.74"), "64.74")


class TestRegionRegistry(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.provinces = read_csv("provinces.csv")
        cls.regions = read_csv("regions_kabkota.csv")
        cls.registry = json.loads((GEO / "region_registry.json").read_text(encoding="utf-8"))

    def test_counts(self):
        self.assertEqual(len(self.provinces), 38)
        self.assertEqual(len(self.regions), 514)
        self.assertEqual(sum(r["region_level"] == "kabupaten" for r in self.regions), 416)
        self.assertEqual(sum(r["region_level"] == "kota" for r in self.regions), 98)

    def test_id_format_and_uniqueness(self):
        for p in self.provinces:
            self.assertRegex(p["region_id"], r"^\d{2}$")
        ids = [r["region_id"] for r in self.regions]
        self.assertEqual(len(ids), len(set(ids)))
        for r in self.regions:
            self.assertRegex(r["region_id"], r"^\d{2}\.\d{2}$")
            self.assertRegex(r["kode_bps"], r"^\d{4}$")

    def test_hierarchy(self):
        prov_ids = {p["region_id"] for p in self.provinces}
        for r in self.regions:
            self.assertIn(r["parent_region_id"], prov_ids)
            self.assertTrue(r["region_id"].startswith(r["parent_region_id"] + "."))

    def test_every_province_has_regions(self):
        used = {r["parent_region_id"] for r in self.regions}
        self.assertEqual(used, {p["region_id"] for p in self.provinces})

    def test_every_region_has_geometry_reference(self):
        for r in self.regions:
            self.assertTrue(r["big_objectids"], r["region_id"])

    def test_known_papua_code_divergence(self):
        # BPS and Kemendagri number the Papua provinces differently; the
        # crosswalk must preserve that rather than "fix" it.
        by_id = {p["region_id"]: p for p in self.provinces}
        self.assertEqual(by_id["91"]["kode_bps"], "94")   # Papua
        self.assertEqual(by_id["96"]["kode_bps"], "92")   # Papua Barat Daya

    def test_no_zero_used_for_unknown(self):
        for r in self.regions:
            self.assertNotEqual(r["big_luaswh_raw"], "0", r["region_id"])

    def test_raw_inputs_unchanged(self):
        for item in self.registry["inputs"]:
            self.assertEqual(sha256_file(REPO_ROOT / item["path"]), item["sha256"], item["path"])

    def test_raw_sidecars_match_files(self):
        for meta_path in (REPO_ROOT / "data" / "raw").rglob("*.meta.json"):
            meta = json.loads(meta_path.read_text(encoding="utf-8"))
            data_path = meta_path.with_name(re.sub(r"\.meta\.json$", "", meta_path.name))
            self.assertEqual(sha256_file(data_path), meta["sha256"], str(data_path))


if __name__ == "__main__":
    unittest.main()
