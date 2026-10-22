# 28 GEOGRAPHY DATA PIPELINE

Technical reference for the geography baseline: snapshot `SNAP-2026-10-21`. It implements docs/08 (map and GIS) and docs/04 (data research) for the provinsi and kab/kota levels.

## 1. Sources

| ID | Source | Role |
|---|---|---|
| SRC-0001 | BIG `BATAS_KABKOTA_AR`, *edisi Juni 2026*, 1:50.000, EPSG:4326 | Authoritative kab/kota polygons (raw, full resolution) |
| SRC-0002 | BPS SIG bridging BPS↔Kemendagri, period `2025_2.2025` | Official codes and crosswalk |
| SRC-0007 | BIG `BATAS_WILAYAH` layer 8, province boundary lines (2021-05 to 2024-09) | Independent cross-check of the dissolved province outlines |
| SRC-0008 | BPS provincial "Luas Daerah dan Jumlah Pulau" tables (2025/2024) | Independent official area figures |
| SRC-0003/0004/0006 | Kemendagri decree PDF, kodewilayah portal, 2025 amendment | Blocked or not located (GAP-0001/0002/0003) |

## 2. Keys and hierarchy

- `region_id` is the Kemendagri code: `PP` for a province, `PP.KK` for a kab/kota (D-050). `kode_bps` is a lookup column only. The six Papua provinces have different BPS and Kemendagri codes.
- Hierarchy: Indonesia → 38 provinsi → 514 kab/kota (416 kabupaten + 98 kota). Simulation regions are the 514 kab/kota (D-052).
- Navigation groups are presentation-only (`data/design/navigation_groups.json`, D-054). There are seven groups covering all 38 provinces, each province exactly once. They are never written into the official registry.

## 3. Raw capture

- Code: `scripts/pipelines/geo/v2/common.py`. Captures are cached and immutable, with a `.meta.json` sidecar per file (URL, retrieved_at, sha256, bytes). Every attempt is logged in `data/catalog/source_access_log.csv`. Requests are at least 1 s apart, with up to 4 attempts and exponential backoff.
- BIG polygons are captured as GeoJSON in pages of 10 features. A page the server cannot serialize (HTTP 500) is retried one feature at a time.
- Kab. Sumbawa (OBJECTID 3424) cannot be served at full resolution in any format, so it is captured with `maxAllowableOffset = 1e-7°`, a maximum deviation of about 1.1 cm (D-056, GAP-0010).
- Completeness check: `check_big_geometry.py` → `research/reports/geometry_capture_check.json`. It verifies 541/541 features, the sha256 and size of every page, the feature count per page, and that there are no duplicates or empty geometries.

## 4. Region registry

`build_region_registry.py` joins the BPS bridge to the BIG attributes (`data/normalized/geography/`):
- **Code repair:** the BPS bridge drops trailing zeros in some Kemendagri codes (`11.1` → `11.10`). These are repaired by a tested rule, and the raw value is kept.
- **Join:** every one of the 514 regions matches exactly one main BIG polygon.
- **Extra BIG pieces:** 6 "Wilayah terapung" parts are attached to their region, and the 21 `TIPADM=6` fragments are kept as a separate render-only layer.

## 5. Render LODs

`build_render_geometry.py`, mapshaper 0.7.79 (project-local, `tools/geo/`), two passes per LOD (D-053):

1. **Pass A:**
   - merge raw pages, split off the fragments, dissolve by `KDPKAB` (attaches the terapung parts);
   - join registry fields (`region_id, kode_bps, parent_region_id, province_kode_bps, region_level, name, nav_group_key`);
   - explode to single parts;
   - simplify with Douglas–Peucker (spherical), `interval=<m>`, `keep-shapes`, intersection repair on;
   - write the simplified parts at 1e-6°.
2. **Pass B**, on the re-imported, already-simplified geometry:
   - `-clean gap-width=0`, then re-dissolve per region;
   - `-snap precision=1e-6 fix-geometry`, then `-clean` again;
   - dissolve provinces from the final kab/kota layer, so province borders are identical to kab/kota borders;
   - write RFC 7946 GeoJSON.

| LOD | Interval | Use (view width, ~1,600 px viewport) |
|---|---|---|
| lod1 | 1,000 m | national, ≥ 2,000 km |
| lod2 | 100 m | island group / province, 300–2,000 km |
| lod3 | 40 m | kab/kota, < 300 km |

Outputs are in `data/processed/geography/SNAP-2026-10-21/render/<lod>/`: `kabkota.json` (514 features), `provinsi.json` (38), `fragments.json` (21) and `build_log.json`, which records the exact commands, mapshaper version, statistics and messages.

The intervals come from a documented selection rule over 19 candidates covering two methods (`research/reports/lod_tolerance_selection.json`). That file states which criteria were set after metrics had been seen.

The game loads these files offline. Nothing calls BIG at runtime.

## 6. Validation

| Check | Script | Report |
|---|---|---|
| Counts, IDs, codes, parents, names, groups preserved; structural validity; no segment crossings; no containment overlaps; adjacency equal to raw source (997 pairs, shared vertex at 1e-6°, all owners per vertex); island survival | `validate_render_geometry.py` | `render_geometry_validation.json` |
| Fate of every raw source part per LOD (distinct / absorbing / merged / deformed / displaced / lost), with a noticeability criterion | `audit_island_components.py` | `island_component_audit.json` |
| Dissolved province outlines vs BIG province lines | `compare_province_lines.py` | `province_outline_crosscheck.json` |
| Visual previews: national, provincial and kab/kota windows, with the raw outline overlaid | `render_previews.py` | `geometry_previews/*.png` |
| File size and JSON parse time (proxy; Godot not installed) | `measure_load_times.py` | `lod_load_times.json` |
| Unit tests and regression tests | `scripts/pipelines/geo/v2/tests/` | `python3 -m unittest discover -s scripts/pipelines/geo/v2/tests` |

Adjacency reference: `compute_source_adjacency.py` → `fullres_adjacency.json`.

## 7. Area fields (D-055)

- `LUASWH` is kept raw. Its declared label "(HA)" sits beside the evidenced interpretation, km² legal area (`UNIT_KM2_EVIDENCED`).
- `Shape_Area` is planar square degrees.
- `geom_area_km2` is derived and stored separately. Its method: the WGS84 ellipsoidal cylindrical equal-area projection (authalic latitude), then the shoelace formula, tested against numerical integration.
- See `research/reports/2026-10-22_AREA_UNIT_INVESTIGATION.md`.

## 8. Reproduce

See `scripts/pipelines/geo/v2/README.md`.

## 9. Known limitations

- **Small islands are distorted.** Douglas–Peucker shrinks small islands by a median area ratio of about 0.4–0.5 among deformed parts. Islets and sandbars narrower than about 1 px at a LOD's reference scale may be drawn as slivers. Every region keeps its identity, and no noticeable part is displaced or lost (island audit).
- **Province outlines are derived.** No current official province polygon layer exists. The cross-check uses older province lines (≤ 2024-09).
- **Godot load time is not yet measured.** Coordinates in Godot are float32 by default (about 0.85 m at these longitudes). A local or projected coordinate transform is recommended when exporting to the engine.
- **Sumbawa is a recovery copy**, not full resolution (about 1.1 cm deviation).
