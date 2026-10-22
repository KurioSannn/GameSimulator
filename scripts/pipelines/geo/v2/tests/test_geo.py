"""Unit tests for scripts/pipelines/geo/v2/geo.py."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from geo import area_km2, find_crossings, structural_problems  # noqa: E402


def box(x0, y0, x1, y1):
    return {"type": "Polygon", "coordinates": [[[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]]]}


class TestArea(unittest.TestCase):
    @staticmethod
    def reference_cell_km2(lat0, lat1, dlon_deg, n=2000):
        """Independent reference: Simpson integration of the WGS84 area element
        dA = M(lat) * N(lat) * cos(lat) dlat dlon (M, N = meridional / prime-vertical radii)."""
        import math
        a, e2 = 6378137.0, 0.00669437999014

        def f(phi):
            w = 1 - e2 * math.sin(phi) ** 2
            return (a * (1 - e2) / w ** 1.5) * (a / w ** 0.5) * math.cos(phi)

        p0, p1 = math.radians(lat0), math.radians(lat1)
        h = (p1 - p0) / n
        s = f(p0) + f(p1) + sum((4 if i % 2 else 2) * f(p0 + i * h) for i in range(1, n))
        return s * h / 3 * math.radians(dlon_deg) / 1e6

    def test_cells_match_numerical_integration(self):
        # Edges follow parallels/meridians, which are straight in the cylindrical
        # equal-area projection, so the result should match the integral closely.
        for lat0, lat1 in [(0, 1), (-11, -10), (5, 6), (-8, -2)]:
            ref = self.reference_cell_km2(lat0, lat1, 1)
            self.assertAlmostEqual(area_km2(box(120, lat0, 121, lat1)), ref, delta=ref * 1e-9)

    def test_area_is_orientation_independent_and_holes_subtract(self):
        outer = [[100, -1], [101, -1], [101, 0], [100, 0], [100, -1]]
        hole = [[100.25, -0.75], [100.25, -0.25], [100.75, -0.25], [100.75, -0.75], [100.25, -0.75]]
        a_ccw = area_km2({"type": "Polygon", "coordinates": [outer]})
        a_cw = area_km2({"type": "Polygon", "coordinates": [outer[::-1]]})
        self.assertAlmostEqual(a_ccw, a_cw, places=6)
        with_hole = area_km2({"type": "Polygon", "coordinates": [outer, hole]})
        self.assertAlmostEqual(with_hole, a_ccw * 0.75, delta=a_ccw * 0.001)

    def test_multipolygon_sums(self):
        mp = {"type": "MultiPolygon", "coordinates": [box(100, 0, 101, 1)["coordinates"],
                                                       box(102, 0, 103, 1)["coordinates"]]}
        self.assertAlmostEqual(area_km2(mp), 2 * area_km2(box(100, 0, 101, 1)), places=6)


class TestValidity(unittest.TestCase):
    def test_clean_box(self):
        self.assertEqual(structural_problems(box(100, 0, 101, 1)), [])

    def test_unclosed_and_outside(self):
        g = {"type": "Polygon", "coordinates": [[[10, 0], [11, 0], [11, 1], [10, 1]]]}
        probs = structural_problems(g)
        self.assertTrue(any("not closed" in p for p in probs))
        self.assertTrue(any("outside bbox" in p for p in probs))

    def test_bowtie_self_intersection(self):
        bowtie = {"type": "Polygon", "coordinates": [[[100, 0], [101, 1], [101, 0], [100, 1], [100, 0]]]}
        hits = find_crossings([("a", bowtie)])
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0][0], "a")

    def test_shared_border_is_not_a_crossing(self):
        self.assertEqual(find_crossings([("a", box(100, 0, 101, 1)), ("b", box(101, 0, 102, 1))]), [])

    def test_overlap_detected(self):
        hits = find_crossings([("a", box(100, 0, 101, 1)), ("b", box(100.5, 0.5, 101.5, 1.5))])
        self.assertTrue(hits)
        self.assertEqual({hits[0][0], hits[0][1]}, {"a", "b"})



class TestTopologyHelpers(unittest.TestCase):
    def test_interior_point_avoids_hole(self):
        from geo import interior_point, point_in_polygon
        outer = [[0, 0], [4, 0], [4, 4], [0, 4], [0, 0]]
        hole = [[1, 1], [3, 1], [3, 3], [1, 3], [1, 1]]
        pt = interior_point([outer, hole])
        self.assertTrue(point_in_polygon(pt, [outer, hole]))
        self.assertFalse(point_in_polygon(pt, [hole]))

    def test_enclave_overlap_detected_without_crossings(self):
        from geo import find_containment_overlaps
        big = box(100, 0, 104, 4)          # hole collapsed: covers the enclave
        enclave = box(101, 1, 102, 2)
        hits = find_containment_overlaps([("kab", big), ("kota", enclave)])
        self.assertEqual([(a, b) for a, b, _ in hits], [("kota", "kab")])
        self.assertEqual(find_crossings([("kab", big), ("kota", enclave)]), [])

    def test_enclave_with_hole_is_clean(self):
        from geo import find_containment_overlaps
        outer = [[100, 0], [104, 0], [104, 4], [100, 4], [100, 0]]
        hole = [[101, 1], [101, 2], [102, 2], [102, 1], [101, 1]]
        kab = {"type": "Polygon", "coordinates": [outer, hole]}
        self.assertEqual(find_containment_overlaps([("kab", kab), ("kota", box(101, 1, 102, 2))]), [])

    def test_vertex_adjacency(self):
        from geo import vertex_adjacency
        pairs = vertex_adjacency([("a", box(100, 0, 101, 1)), ("b", box(101, 0, 102, 1)),
                                  ("c", box(105, 0, 106, 1))])
        self.assertEqual(pairs, {("a", "b")})

    def test_vertex_adjacency_three_way_junction(self):
        # regression: b and c touch only at the vertex shared by a, b and c
        from geo import vertex_adjacency
        a = {"type": "Polygon", "coordinates": [[[100, 0], [101, 0], [101, 1], [100, 1], [100, 0]]]}
        b = {"type": "Polygon", "coordinates": [[[101, 0], [102, 0], [101, 1], [101, 0]]]}
        c = {"type": "Polygon", "coordinates": [[[101, 1], [102, 0], [102, 2], [101, 1]]]}
        self.assertEqual(vertex_adjacency([("a", a), ("b", b), ("c", c)]),
                         {("a", "b"), ("a", "c"), ("b", "c")})


if __name__ == "__main__":
    unittest.main()
