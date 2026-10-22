"""Unit tests for research pipelines. Run: .venv/bin/python -m unittest discover -s scripts/tests -v

All fixtures are SYNTHETIC (invented numbers) and exist only to test parsing/calibration logic.
"""
from __future__ import annotations

import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from connectors import bps_webapi  # noqa: E402
from lib import observations  # noqa: E402
from pipelines.calibration import build_baseline  # noqa: E402

FIX = Path(__file__).parent / "fixtures"


def obs(var, rid, val, period="2024", res=None, unit="indeks"):
    return {"obs_variable_id": var, "region_id": rid, "resolution": res or ("provinsi" if len(rid) == 2 else "kabkota"),
            "value": val, "reference_period": period, "unit": unit, "source_id": "SRC-TEST",
            "dataset_ref": f"test:{var};th={period}", "retrieved_at": "2026-10-05", "raw_path": "test",
            "fact_class": "REAL_OFFICIAL"}


class BpsParserTests(unittest.TestCase):
    def setUp(self):
        self.payload = json.loads((FIX / "bps_data_synthetic.json").read_text(encoding="utf-8"))

    def parse(self, payload=None):
        return bps_webapi.parse_data(payload or self.payload, obs_variable_id="test_var", unit="indeks",
                                     domain="3200", raw_path="fixture", retrieved_at="2026-10-05")

    def test_parses_kabkota_rows_and_skips_province_row(self):
        rows = self.parse()
        ids = {(r["region_id"], r["reference_period"]) for r in rows}
        self.assertIn(("32.01", "2024"), ids)
        self.assertNotIn(("32.00", "2024"), ids)
        self.assertEqual(len(rows), 5)
        self.assertEqual(next(r for r in rows if r["region_id"] == "32.76")["value"], 44.4)

    def test_dash_becomes_not_published_not_zero(self):
        r = next(r for r in self.parse() if r["region_id"] == "32.75" and r["reference_period"] == "2025")
        self.assertIsNone(r["value"])
        self.assertEqual(r["missing_class"], "NOT_PUBLISHED")

    def test_rows_pass_observation_schema(self):
        observations.validate(self.parse())

    def test_unknown_key_raises(self):
        p = copy.deepcopy(self.payload)
        p["datacontent"]["999999"] = 1
        with self.assertRaises(bps_webapi.BpsFormatError):
            self.parse(p)

    def test_not_ok_raises(self):
        p = copy.deepcopy(self.payload)
        p["status"] = "Error"
        with self.assertRaises(bps_webapi.BpsFormatError):
            self.parse(p)

    def test_kab_code_conversion(self):
        self.assertEqual(bps_webapi.bps_kab_code(3201), "32.01")
        self.assertIsNone(bps_webapi.bps_kab_code("3200"))
        self.assertIsNone(bps_webapi.bps_kab_code("32"))


class ObservationTests(unittest.TestCase):
    def test_value_and_missing_are_exclusive(self):
        bad = obs("x", "32.01", 1.0)
        bad["missing_class"] = "NOT_PUBLISHED"
        with self.assertRaises(observations.ObservationError):
            observations.validate([bad])

    def test_duplicates_rejected(self):
        with self.assertRaises(observations.ObservationError):
            observations.validate([obs("x", "32.01", 1.0), obs("x", "32.01", 2.0)])

    def test_roundtrip(self):
        with tempfile.TemporaryDirectory() as d:
            observations.write("x", [obs("x", "32.01", 1.5)], Path(d))
            self.assertEqual(observations.read("x", Path(d))[0]["value"], 1.5)


class CalibrationTests(unittest.TestCase):
    REGIONS = ["32.01", "32.75", "33.01"]
    VMAP = {"neutral_defaults": {"welfare_base": 55.0, "welfare": 55.0, "infrastructure": 50.0, "population": 0.0},
            "rules": {"welfare_base": {"rule": "identity", "inputs": ["ipm"], "fallback": "province_proxy", "clamp": [0, 100]},
                      "welfare": {"rule": "copy", "from": "welfare_base"},
                      "infrastructure": {"rule": "ratio_pct", "inputs": ["good", "total"], "fallback": "none", "clamp": [0, 100]},
                      "population": {"rule": "identity", "inputs": ["pop"], "fallback": "none"}}}

    def run_build(self, data):
        return build_baseline.build(self.VMAP, list(self.VMAP["neutral_defaults"]), self.REGIONS, lambda v: data.get(v, []))

    def test_real_proxy_and_uncalibrated_statuses(self):
        data = {"ipm": [obs("ipm", "32.01", 70.0), obs("ipm", "32.75", 80.0), obs("ipm", "33", 72.0)]}
        out, _ = self.run_build(data)
        wb = out["welfare_base"]
        self.assertEqual(wb["region_status"], ["REAL", "REAL", "PROVINCE_PROXY"])
        self.assertEqual(wb["values"], [70.0, 80.0, 72.0])
        self.assertEqual(wb["status"], "DERIVED")
        self.assertEqual(out["welfare"]["values"], wb["values"])
        self.assertEqual(out["population"]["status"], "UNCALIBRATED")

    def test_missing_without_fallback_uses_labeled_default(self):
        data = {"good": [obs("good", "32.01", 30.0), obs("good", "32.75", 0.0)],
                "total": [obs("total", "32.01", 60.0), obs("total", "32.75", 0.0)]}
        out, _ = self.run_build(data)
        inf = out["infrastructure"]
        self.assertEqual(inf["values"][0], 50.0)  # 100 * 30/60
        self.assertEqual(inf["region_status"], ["REAL", "UNCALIBRATED", "UNCALIBRATED"])  # 0/0 not invented

    def test_period_choice_prefers_latest_with_coverage(self):
        data = {"ipm": [obs("ipm", r, 60.0, "2024") for r in self.REGIONS] + [obs("ipm", "32.01", 61.0, "2025")]}
        out, _ = self.run_build(data)
        self.assertEqual(out["welfare_base"]["reference_period"], "2024")  # 2025 covers only 1/3 regions
        self.assertEqual(out["welfare_base"]["values"][0], 60.0)  # years are never mixed

    def test_full_real_identity_is_real_official(self):
        data = {"pop": [obs("pop", r, 1000.0, unit="jiwa") for r in self.REGIONS]}
        out, _ = self.run_build(data)
        self.assertEqual(out["population"]["status"], "REAL_OFFICIAL")

    def test_duplicate_observation_is_error(self):
        data = {"ipm": [obs("ipm", "32.01", 70.0), dict(obs("ipm", "32.01", 71.0), dataset_ref="other")]}
        with self.assertRaises(ValueError):
            self.run_build(data)


if __name__ == "__main__":
    unittest.main()


class GammaPoissonTests(unittest.TestCase):
    ORDER = ["11.01", "11.02", "11.03", "11.04", "12.01", "12.02", "12.03", "13.01"]

    def rows(self, data):
        return [obs("bnpb_flood_events", rid, v, period=p, unit="kejadian") for rid, p, v in data]

    def run_rule(self, data):
        return build_baseline.gamma_poisson_rate({"rule": "gamma_poisson_rate"}, self.rows(data), self.ORDER)

    def test_zero_record_is_not_zero_rate(self):
        g = self.run_rule([("11.01", "2024", 0), ("11.02", "2024", 6), ("11.03", "2024", 2), ("12.01", "2024", 9),
                           ("12.02", "2024", 1), ("12.03", "2024", 0)])
        i = self.ORDER.index("11.01")
        self.assertGreater(g["values"][i], 0.0)
        self.assertEqual(g["status"][i], "REAL")

    def test_province_all_zero_still_positive(self):
        g = self.run_rule([("11.01", "2024", 0), ("11.02", "2024", 0), ("11.03", "2024", 0), ("12.01", "2024", 9),
                           ("12.02", "2024", 3), ("12.03", "2024", 5)])
        self.assertTrue(all(v > 0 for v in g["values"]))

    def test_missing_region_gets_labeled_proxy(self):
        g = self.run_rule([("11.01", "2024", 1), ("11.02", "2024", 4), ("11.03", "2024", 2), ("12.01", "2024", 9)])
        self.assertEqual(g["status"][self.ORDER.index("11.04")], "PROVINCE_PROXY")  # province 11 has >= 3 observed
        self.assertEqual(g["status"][self.ORDER.index("13.01")], "UNCALIBRATED")    # no province data -> national prior
        self.assertGreater(g["values"][self.ORDER.index("13.01")], 0.0)

    def test_more_years_move_toward_own_mean(self):
        base = [("11.02", "2024", 6), ("11.03", "2024", 2), ("12.01", "2024", 9), ("12.02", "2024", 1)]
        one = self.run_rule(base + [("11.01", "2024", 10)])
        many = self.run_rule(base + [("11.01", y, 10) for y in ("2020", "2021", "2022", "2023", "2024")])
        i = self.ORDER.index("11.01")
        self.assertLess(abs(many["values"][i] - 10), abs(one["values"][i] - 10))


class BpsWorkflowTests(unittest.TestCase):
    def test_bulk_refuses_unconfirmed_indicators(self):
        from pipelines.bps import bps_workflow
        ok, missing = bps_workflow.approved({"var_id": 1, "title": "x", "unit": "persen", "year": 2024,
                                             "level": "kabkota", "region_coding": "bps4", "domain_scope": "province",
                                             "sample_checked": False})
        self.assertFalse(ok)
        self.assertIn("sample_checked", missing)
        ok2, _ = bps_workflow.approved({"var_id": 1, "title": "x", "unit": "persen", "year": 2024, "level": "kabkota",
                                        "region_coding": "bps4", "domain_scope": "province", "sample_checked": True})
        self.assertTrue(ok2)

    def test_shipped_approvals_are_all_unconfirmed(self):
        from pipelines.bps import bps_workflow
        appr = json.loads(bps_workflow.APPROVALS.read_text(encoding="utf-8"))["indicators"]
        self.assertTrue(all(not bps_workflow.approved(v)[0] for v in appr.values()), "no indicator pre-approved without a real key")

    def test_missing_key_exits(self):
        import os
        from unittest import mock
        with mock.patch.dict(os.environ, {"BPS_API_KEY": ""}), mock.patch.object(bps_webapi, "REPO_ROOT", Path(tempfile.mkdtemp())):
            with self.assertRaises(SystemExit):
                bps_webapi.load_key()


class PinnedYearsTests(unittest.TestCase):
    def test_production_frequency_uses_only_pinned_years(self):
        vmap = {"neutral_defaults": {"flood_frequency": 0.0},
                "rules": {"flood_frequency": {"rule": "gamma_poisson_rate", "inputs": ["ev"], "years": ["2024"]}}}
        regions = ["11.01", "11.02", "11.03"]
        data = {"ev": [obs("ev", r, 2.0, "2024", unit="kejadian") for r in regions] +
                      [obs("ev", "11.01", 50.0, "2010", unit="kejadian")]}
        out, _ = build_baseline.build(vmap, ["flood_frequency"], regions, lambda v: data.get(v, []))
        self.assertEqual(out["flood_frequency"]["reference_period"], "2024")
        self.assertLess(out["flood_frequency"]["values"][0], 5.0, "2010 candidate year must not leak into production")
