# RESEARCH BOOTSTRAP REPORT: Geography baseline

- **Snapshot:** `SNAP-2026-10-21` (open; geography milestone closed 2026-10-22)
- **Date:** 2026-10-21
- **Executor:** Claude Code (see `AI_USAGE_LOG.md`)
- **Scope:** first data milestone from `prompts/RESEARCH_BOOTSTRAP_PROMPT.md`: official region codes, province and kab/kota registries, current boundary source, geography crosswalk, snapshot metadata.

## 1. Attempted

1. Find the legal source for current administrative codes (Kemendagri).
2. Find the current official boundary geometry (BIG).
3. Find an official, machine-readable code list and BPS↔Kemendagri crosswalk.
4. Capture raw data with checksums and an access log, normalize it, cross-validate the sources, and write tests.

## 2. Succeeded

| Item | Result | Evidence |
|---|---|---|
| Province count | **38**, confirmed by BPS bridge and BIG | `data/normalized/geography/provinces.csv` |
| Kab/kota count | **514 = 416 kabupaten + 98 kota**, confirmed independently by BPS (Kemendagri names) and BIG (`TIPADM`) | `regions_kabkota.csv` |
| Code crosswalk | 552 rows (38 + 514), BPS ↔ Kemendagri | `crosswalk_bps_kemendagri.csv` |
| Boundary source | BIG `BATAS_KABKOTA_AR`, *edisi Juni 2026*, 1:50.000, EPSG:4326 | SRC-0001 |
| BIG ↔ registry join | 514/514 regions have exactly one main BIG polygon; no orphan polygons | `research/reports/geography_validation.json` |
| Raw capture | immutable, SHA-256 sidecars, every request logged | `data/raw/`, `data/catalog/source_access_log.csv` |
| Tests | 11/11 pass | `scripts/pipelines/geo/v2/tests/` |

### Key findings

- **The Papua province codes differ between agencies.** Kemendagri / BPS: Papua 91/94, Papua Barat 92/91, Papua Selatan 93/95, Papua Tengah 94/96, Papua Pegunungan 95/97, Papua Barat Daya 96/92. All BPS data must be joined through the crosswalk (decision D-050).
- **The BPS bridge serves malformed Kemendagri codes.** 23 kab/kota codes lose a trailing zero (`11.1` instead of `11.10`). They are repaired by a documented, tested rule, the raw value is kept in `kode_kemendagri_raw`, and BIG confirms all 23.
- **BIG's 541 features include non-region pieces.** Besides the 514 main polygons, there are 6 "Wilayah terapung" secondary polygons (Sulawesi Tenggara: 74.02, 74.03, 74.04, 74.05, 74.07, 74.13) and 21 `TIPADM=6` fragments: province-level islands not assigned to any kab/kota, plus Danau Moat, which BIG marks "area bermasalah". The fragments are listed in `big_unallocated_fragments.csv` and are not simulation regions (D-052).
- **One BIG layer is mislabelled.** `BATAS_WILAYAH` layer 12, titled "Provinsi", actually contains older (2024-09) kab/kota polygons. It is marked deprecated (SRC-0005).

## 3. Failed

| Attempt | Failure | Logged as |
|---|---|---|
| Download the Kepmendagri 300.2.2-2138/2025 PDF from Ditjen Bina Adwil | Broken relative link; HTTP 400/404 at every plausible path | SRC-0003 `blocked`, GAP-0001 |
| `kodewilayah.kemendagri.go.id` | Redirects to a login page; not bypassed | SRC-0004 `blocked`, GAP-0002 |
| BPS `/rest-bridging/getwilayahperiode` | HTTP 500 | SRC-0002 notes |
| BIG geometry page at offset 50 (10 features) | HTTP 500, repeated | access log; fetcher now falls back to single-feature requests |

## 4. Skipped (deliberately)

- Kecamatan and desa codes (GAP-0008): the simulation unit is kab/kota.
- ~~Render-geometry simplification and the province dissolve~~: done on 2026-10-22 with project-local mapshaper (§8).
- All non-geography domains: per the bootstrap prompt, they wait until the geography contract exists.

## 5. Coverage

| Level | Target | Covered | Source |
|---|---|---|---|
| Provinsi codes | 38 | 38 | BPS bridge (Kemendagri codes) |
| Kab/kota codes | 514 | 514 | BPS bridge |
| Kab/kota polygons | 514 | 514: full-resolution raw (541 features) plus 3 render LODs | BIG edisi Juni 2026 |
| Province polygons | 38 | 38, dissolved from kab/kota per LOD (no current official layer, GAP-0006) | derived from BIG |
| Navigation groups | 38 provinces | 38, each in exactly one of 7 groups | team design (D-054) |
| Official kab/kota area figures | 514 | 447 (BPS tables; 17 flagged anomalous) | BPS SRC-0008 |

## 6. Known gaps and contradictions

See `data/catalog/gap_registry.csv` (GAP-0001 to GAP-0014). The most important are:

- **GAP-0003, decree number.** Still open. BIG remarks cite "Kepmendagri 300.2.2-**2340**", and secondary sources cite **2430**. Every BPS 2025 area table that names a 2025 decree cites 300.2.2-**2138** only. This is bibliographic and does not block the registry or the geometry.
- **GAP-0004, `LUASWH` unit.** Resolved by evidence. The values are km² legal area despite the "(HA)" alias, and they are kept raw, with the evidenced unit stored as separate metadata (`2026-10-22_AREA_UNIT_INVESTIGATION.md`, D-055).
- **GAP-0009, BPS WebAPI key.** A key is needed before demography and economy ingestion.
- **GAP-0010, Sumbawa.** Full resolution is not served, so a 1e-7° recovery copy is used (D-056).
- **GAP-0011, area tables.** There are no BPS area tables for 7 provinces.

## 7. Raw geometry capture (completed 2026-10-22)

- **Completeness:** 541 of 541 features in 118 files, 2.22 GB, 51.9 M vertices. Every file's sha256, size and feature count verify (`research/reports/geometry_capture_check.json`).
- **Server errors:** BIG returned HTTP 500 for four 10-feature pages, which were recovered one feature at a time, and for OBJECTID 3424 at full resolution in every format, which was recovered with `maxAllowableOffset = 1e-7°`.
- **Unlogged requests:** the diagnostic requests made by hand with curl while investigating 3424 (f=json, f=pbf, maxAllowableOffset 1e-6/1e-8/1e-9) are not in the access log. They are recorded here and in SRC-0001 and GAP-0010.

## 8. Geography baseline completion (2026-10-22)

| Deliverable | Location |
|---|---|
| Raw geometry inventory | `geometry_capture_check.json`, `data/raw/SRC-0001/**/*.meta.json` |
| Render LODs (Douglas–Peucker 1,000 / 100 / 40 m) | `data/processed/geography/SNAP-2026-10-21/render/lod{1,2,3}/` (DATA-0003) |
| Province outlines (dissolved, per LOD) | `render/lod*/provinsi.json`; cross-check `province_outline_crosscheck.json` |
| Seven navigation groups | `data/design/navigation_groups.json` (D-054) |
| Area-unit investigation | `2026-10-22_AREA_UNIT_INVESTIGATION.md`, `area_unit_audit.csv` |
| Validation | `2026-10-22_GEOMETRY_VALIDATION_REPORT.md`, `render_geometry_validation.json`, `island_component_audit.json` |
| Tolerance selection evidence | `lod_tolerance_selection.json` (19 candidates, 2 methods) |
| Previews and load timings | `geometry_previews/`, `lod_load_times.json` |
| Technical documentation | `docs/29_GEOGRAPHY_DATA_PIPELINE.md` |

Results:
- **Hard checks:** 15/15 per LOD. That covers 514/514 IDs and codes preserved, zero crossings, zero containment overlaps, adjacency of 997/997 pairs, and island survival.
- **Island audit:** 0 lost and 0 noticeable parts displaced.
- **Province cross-check:** median 7.5 m from the official inter-province lines, 99.75 % within 50 m.
- **Size:** 48.9 MB across the three LODs against 2.22 GB raw.
- **Tests:** 44 of 44 pass, 0 skipped.

## 9. Reproduce

See `scripts/pipelines/geo/v2/README.md`.

## 10. Next actions

1. **Team:** register a BPS WebAPI key (GAP-0009); obtain the official Kepmendagri 300.2.2-2138/2025 PDF, for example via JDIH id=1937 from another network (GAP-0001); confirm the BIG reuse terms.
2. **Godot export of the LODs:** local or projected coordinates for float32, a packed binary format, and in-engine load-time measurement (GAP-0013).
3. **P0 domain ingestion** through the crosswalk: population, PDRB, poverty, IPM, and APBD (DJPK).
