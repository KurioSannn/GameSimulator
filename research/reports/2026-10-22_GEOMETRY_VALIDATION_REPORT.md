# GEOMETRY VALIDATION REPORT: geography baseline LODs

- **Snapshot:** `SNAP-2026-10-21`
- **Validated:** 2026-10-22
- **Method:** Douglas–Peucker (spherical), mapshaper 0.7.79, two-pass build, coordinates at 1e-6° (D-053)
- **Machine-readable reports** (all in `research/reports/`):
  - `render_geometry_validation.json`
  - `island_component_audit.json`
  - `province_outline_crosscheck.json`
  - `lod_tolerance_selection.json`
  - `lod_load_times.json`
  - `geometry_capture_check.json`

## 1. Raw source capture

| Item | Result |
|---|---|
| BIG features expected / captured | 541 / **541** |
| Raw files / size / vertices | 118 files, **2,219,946,824 bytes** (2.22 GB), **51,894,237** kab/kota vertices |
| SHA-256 + byte size per file vs sidecar | all match (`page_integrity_problems: []`; test `test_raw_sidecars_match_files`) |
| Feature count per page, duplicates, empty geometry | all as expected / none / none |
| Not full resolution | 1 declared recovery copy: OBJECTID 3424, Kab. Sumbawa, `maxAllowableOffset = 1e-7°` (about 1.1 cm). The server returns HTTP 500 at full resolution (D-056, GAP-0010). |
| Raw geometry modified? | No. The raw store is immutable and checked by sha256 in every test run. |

## 2. Production LODs: size and complexity

| LOD | Interval | kabkota.json | provinsi.json | fragments.json | Total | kab/kota vertices | province vertices |
|---|---|---|---|---|---|---|---|
| lod1 | 1,000 m | 2,984,232 B | 2,397,034 B | 8,456 B | **5.39 MB** | 123,110 | 102,495 |
| lod2 | 100 m | 9,179,426 B | 5,988,060 B | 10,000 B | **15.18 MB** | 398,555 | 261,842 |
| lod3 | 40 m | 17,126,244 B | 11,198,332 B | 12,907 B | **28.34 MB** | 752,109 | 493,508 |
| **All LODs** | | | | | **48.90 MB** | | |
| Raw source | full resolution | | | | 2,219.95 MB | 51,894,237 | n/a |

- **Size reduction**, raw to a single LOD: lod1 412× (5.39 MB), lod2 146× (15.18 MB), lod3 78× (28.34 MB). All three LODs together are **45.4×** smaller than the raw source.
- **Vertex reduction**, kab/kota, against 51.9 M raw vertices: lod1 99.76 %, lod2 99.23 %, lod3 98.55 %.

## 3. Hard validation checks

All 15 hard checks pass on each LOD (`validate_render_geometry.py`):

| Check | lod1 | lod2 | lod3 |
|---|---|---|---|
| 514 kab/kota; `region_id` unique and equal to the registry | ✅ | ✅ | ✅ |
| Kemendagri ID, BPS code, parent province, level, name, nav group preserved | ✅ | ✅ | ✅ |
| 38 provinces with codes and nav group; 21 fragments | ✅ | ✅ | ✅ |
| Structural validity: closed rings, ≥ 4 positions, finite, inside the Indonesia bbox, non-zero area | ✅ | ✅ | ✅ |
| No self-intersections or overlaps (proper segment crossings) | ✅ 0 | ✅ 0 | ✅ 0 |
| No containment overlaps (a part lying inside another feature) | ✅ 0 | ✅ 0 | ✅ 0 |
| Adjacency equal to raw source (neighbour pairs) | ✅ 997/997 | ✅ 997/997 | ✅ 997/997 |
| Island survival: every raw part represented in its own region | ✅ | ✅ | ✅ |
| Full-res reference available for every region | ✅ | ✅ | ✅ |

The ID sets are identical across LODs (`cross_lod_id_sets_identical: true`).

**Soft check:** provinces have no crossings at any LOD.

**Gaps and overlaps:**
- No overlaps were introduced: crossing and containment checks are both 0.
- No gaps are filled or created: every `-clean` and `-dissolve` runs with `gap-width=0`, and adjacency is unchanged.
- Gaps or slivers that already exist in the raw source are not repaired. They are kept as published.

**Displacement and area:**

| LOD | Mean displacement | Q1 / Q2 / Q3 | Max (bounded by DP) | Median area error | p95 | Max |
|---|---|---|---|---|---|---|
| lod1 | 167.8 m | 6.3 / 28.4 / 247.1 m | 999.96 m | 0.378 % | 4.27 % | 38.9 % |
| lod2 | 42.5 m | 19.5 / 39.5 / 64.2 m | 99.9997 m | 0.020 % | 0.26 % | 17.8 % |
| lod3 | 18.6 m | 10.2 / 17.6 / 26.9 m | 39.9999 m | 0.007 % | 0.11 % | 5.9 % |

The largest area errors fall on tiny-island regions; the per-region worst cases are listed in the JSON report. mapshaper also reports 16, 12 and 11 collapsed rings for lod1, lod2 and lod3. Since the island audit finds no outer source part lost, and containment checks find no enclave overlap, these collapsed rings are interior rings (holes such as small lakes). Their individual identities were not enumerated.

## 4. Small-island and component preservation

`audit_island_components.py` follows all 23,225 raw source parts:

| Size class | Parts |
|---|---|
| < 100 m² | 2,552 |
| 100 m² – 1,000 m² | 5,529 |
| 1,000 m² – 10,000 m² | 6,507 |
| 10,000 m² – 100,000 m² | 4,041 |
| 0.1 km² – 1 km² | 2,430 |
| 1 km² – 10 km² | 1,123 |
| ≥ 10 km² | 1,043 |

Each part is classified per LOD:

| Status | lod1 | lod2 | lod3 |
|---|---|---|---|
| distinct (its own shape) | 18,308 | 20,595 | 21,395 |
| absorbing (largest of a merged group, still drawn) | 376 | 126 | 66 |
| deformed (own shape, IoU ≥ 0.5 but not covering its centre) | 2,126 | 1,837 | 1,418 |
| merged (joined to a larger part of the same region within tolerance) | 2,223 | 526 | 247 |
| displaced (drawn nearby only) | 192 | 141 | 99 |
| **lost** | **0** | **0** | **0** |
| Regions with geometry | 514 | 514 | 514 |
| Noticeable parts (≥ 4 px long and ≥ 1 px mean width at reference scale) | 1,066 | 3,499 | 7,552 |
| **Noticeable parts displaced or lost** | **0** | **0** | **0** |

Findings:
- **No island is removed at any LOD.** Every raw part is still represented, and every kab/kota keeps its identity. Identity preservation is *not* used as the proof of island visibility; the per-part audit is.
- **Visible but not drawn on their own** (length ≥ 1 px at reference scale): 12 displaced and 3 merged at lod1, 28 and 5 at lod2, 49 and 6 at lod3. None is noticeable. They are hairline sandbars or spits less than 1 px wide, or islets lying within the simplification tolerance of a larger island of the same region. An example is two islets of 0.076 and 0.057 km² merged into Buton (74.04) at lod3.
- **Deformation is real.** Deformed parts keep a median of about 0.42 of their area (p05 about 0.19) at every LOD: Douglas–Peucker reduces islets close to the interval size to a few vertices. This is the known visual cost of the LODs, and small islands look smaller than they are at coarse zoom.
- **Visibility rationale at national scale (lod1, 1,250 m/px).**
  - All 1,066 noticeable parts are drawn.
  - A 17.6 km² exclave of Kab. Karanganyar (33.13), about 10 × 2 km, is drawn at reduced width. Its matching enclave hole in Boyolali shrinks with it because the two share arcs, so there is no overlap.
  - Parts under about 1 px wide are allowed to be slivers at this scale.
- **LOD3 preserves all meaningful small-island geometry.** 7,552 of 7,552 noticeable parts are drawn, and 0 parts are lost.
- **Rejected alternative:** weighted Visvalingam turned 60–80 km² islands into 0.01 km² specks kilometres away at national scale. It was rejected (D-053).

## 5. Province outlines vs the BIG province layer

There is no edisi-Juni-2026 province polygon layer (GAP-0006), so provinces are dissolved from the kab/kota layer, and their borders are identical to kab/kota borders by construction.

BIG's province boundary *lines* (SRC-0007, layer 8, editions 2021-05 to 2024-09) contain kab/kota-level lines with `WAPRO1`/`WAPRO2`. Only lines whose two sides lie in different provinces are province boundaries. Comparing LOD3 province outlines against 66,941 vertex samples from those inter-province lines:

| Metric | Value |
|---|---|
| Median distance | **7.5 m** |
| p90 / p95 | 24.4 m / 29.6 m |
| Within 10 m / 50 m / 100 m / 1 km | 59.5 % / **99.75 %** / 99.81 % / 99.93 % |
| Nearest outline belongs to one of the two provinces on the line | **99.99 %** |
| By line edition, within 50 m | 2022-09: 99.98 %; 2022-12: 99.69 %; 2024-09: 99.16 % |

All 375,377 line samples against the kab/kota borders: median 7.4 m, 99.79 % within 50 m. The residual beyond 100 m (under 0.2 %) is consistent with the June 2026 polygon edition being newer than the lines. One province-name spelling difference was mapped explicitly ("Daerah Istimewa Yogyakarta" = DI YOGYAKARTA).

## 6. Visual inspection

Previews are in `research/reports/geometry_previews/`. Each shows the LOD fill and borders, with the raw source outline overlaid in red (raw simplified to ¼ preview pixel).

| Window | LODs | Observation |
|---|---|---|
| National Indonesia | lod1, lod2 | Whole archipelago; all kab/kota outlined; outer islands present |
| Jawa Timur – Bali | lod1–3 | Bawean, Kangean, Nusa Penida and Gili present; outline matches raw; enclave kota drawn as holes |
| Maluku Utara | lod1–3 | Halmahera and island chains match raw; small islets present |
| Kota Surabaya | lod2, lod3 | Harbour piers and coast follow raw within tolerance; one tiny raw feature near the port merged (audit class "merged") |
| Kepulauan Seribu | lod2, lod3 | All island shapes present and coincident with raw |
| Raja Ampat | lod2, lod3 | Dense islet fields preserved |

The first render attempt cropped wide windows, a Quick Look square-thumbnail behaviour. This was fixed with square framing; it was a preview problem, not a geometry defect.

## 7. Load time (proxy)

Godot is not installed, so these are JSON read-and-parse timings, median of 5 runs, Apple Silicon (`lod_load_times.json`). In-engine load, including conversion to Godot polygons, is not measured (GAP-0013).

| File | Size | Node (V8) | CPython |
|---|---|---|---|
| lod1/kabkota.json | 2.98 MB | 20.9 ms | 49.3 ms |
| lod1/provinsi.json | 2.40 MB | 16.8 ms | 40.4 ms |
| lod2/kabkota.json | 9.18 MB | 57.4 ms | 148.2 ms |
| lod2/provinsi.json | 5.99 MB | 37.6 ms | 102.7 ms |
| lod3/kabkota.json | 17.13 MB | 109.4 ms | 270.7 ms |
| lod3/provinsi.json | 11.20 MB | 78.5 ms | 179.6 ms |

## 8. Precision consistency

| Place | Precision |
|---|---|
| `build_render_geometry.py` (`PRECISION = "0.000001"`), pass A `-o precision=0.000001`, pass B `-snap precision=0.000001` and `-o precision=0.000001` | 1e-6° |
| `build_log.json` (`precision_deg`) for lod1/2/3 | 1e-6 |
| Output coordinates | all rounded to 6 decimals (checked by test `test_precision_and_method_consistent`) |
| DECISIONS.md D-053 | 1e-6° (about 0.11 m) |

## 9. Remaining limitations

1. Small islands near the interval size are drawn shrunken (median area ratio about 0.42 among deformed parts). Sub-pixel slivers may appear at coarse zoom.
2. Province outlines are derived, because no current official province polygon layer exists. They are cross-checked only against older (≤ 2024-09) lines.
3. Sumbawa is a 1.1 cm-tolerance recovery copy, not full resolution.
4. Godot load time is unmeasured. Godot's float32 vectors (about 0.85 m at these longitudes) call for local or projected coordinates when exporting to the engine.
5. Gaps or slivers present in the raw BIG data are kept, not repaired.
6. The tolerance rule is documented, not predeclared. Its history is in `lod_tolerance_selection.json`.
