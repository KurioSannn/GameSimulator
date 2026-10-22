# 30 MAP INTEGRATION (geography v2 → Godot)

How the validated geography (docs/29, D-053) becomes the interactive desktop map. This is the runtime contract; measured results are in `research/reports/2026-10-22_MAP_INTEGRATION_REPORT.md`.

## 1. Files

| File | Role |
|---|---|
| `scripts/pipelines/game/build_map_lods.py` | Offline build: projection, triangulation (via `triangulate_rings.mjs` / earcut 3.2.3), packaging |
| `scripts/pipelines/game/triangulate_rings.mjs` | earcut wrapper (Node, project-local `tools/geo`) |
| `scripts/pipelines/game/build_map_test_points.py` | Independent hit-test fixtures for the Godot tests |
| `game/data/map/v2/kabkota_lod{1,2,3}.json` | Mesh metadata: provenance, projection, region table, ring ranges, section offsets |
| `game/data/map/v2/kabkota_lod{1,2,3}.bin` | Mesh data (little-endian): positions, region-index UVs, triangle and border-line indices, province outlines |
| `game/src/map/map_lod.gd` (`MapLod`) | Loads and validates one LOD (pure data, thread-safe); hit testing |
| `game/src/map/map_view.gd` (`MapView`) | Rendering, LOD selection and preloading, hover/selection outlines, recolouring |
| `game/src/map/map_fill.gdshader` | Fill colour from a per-region lookup texture |
| `game/src/app/main.gd` | Wiring: camera → LOD, LOD status label, "Lihat Provinsi" view |
| `game/src/ui/region_panel.gd` | Kemendagri ID, BPS code, kind and parent province from the registry; province view button |
| `game/src/app/qa_map_bench.gd` | QA only (`-- --map-bench=<dir>`): in-engine measurements and screenshots |
| `game/tests/test_map.gd`, `game/tests/fixtures/map_points.json` | Godot tests and their fixture |
| `scripts/tests/test_map_lods.py` | Python tests: meshes in sync with the validated LODs |

Rebuild after any change to the geography LODs or the game registry:

```sh
.venv/bin/python scripts/pipelines/game/build_map_lods.py
.venv/bin/python scripts/pipelines/game/build_map_test_points.py
```

## 2. Data boundaries

| Layer | Where | Mutable at runtime? |
|---|---|---|
| Source geometry and metadata (lon/lat) | `data/raw/SRC-0001`, `data/processed/geography/SNAP-2026-10-21/render/` | no; never read by the game |
| Canonical IDs and attributes | `game/data/regions.json` (from the registry; now with `kode_bps`) | no |
| Projected render coordinates and meshes | `game/data/map/v2/*` | no |
| Runtime interaction state | `MapView` (active LOD, hover, selection, colours) | yes |
| Simulation state | `SimWorld` | yes; the map only reads colours from a callable |

The map never derives areas or distances (`note` field in every metadata file; D-055). Nothing is fetched at runtime: all paths are `res://`, and a test scans the map code for network APIs.

## 3. Projection and precision

- **Projection:** equirectangular, lon0 = 118°E, standard parallel 2.5°S, 100 units per degree, y down, origin (118°E, 0°). This is the game's existing projection, kept so camera and overlay code stay valid.
  - x = (lon − 118) · cos 2.5° · 100
  - y = −lat · 100
- **Units:** 1 unit = 1/100° of latitude = 1.1119 km on a sphere of R = 6,371 km (`KM_PER_UNIT`).
- **Local origin:** the whole archipelago lies within about x −2,300…+2,300 and y −600…+1,100.
  - At |x| ≤ 2,300, float32 resolution is about 2.7e-4 units (≈ 0.3 m). That is far below the 40 m LOD3 interval, so no double-precision engine build is needed.
- **Distortion:** east–west scale relative to true is cos 2.5° / cos φ.
  - At 11°S (Rote) it is +1.8 %; at 6°N (Sabang, Miangas) about +0.4 %.
  - North–south scale is exact.
  - Shapes are slightly stretched east–west south of about 2.5°S and compressed to the north. This is visual only.
- **Consistency:** the source lon/lat files are untouched; projection happens in `build_map_lods.py` only, identically for all three LODs. `MapView.project_lonlat` is the same formula, checked by test (`test_projection_matches_offline_build_and_is_lod_independent`).
  - Representative points tested include the westernmost, easternmost, northernmost and southernmost islands, plus every part of island regions in Sumatera, Jawa (Kepulauan Seribu), Nusa Tenggara (Rote Ndao), Sulawesi (Wakatobi), Maluku (Kepulauan Aru) and Papua (Raja Ampat).

## 4. Geometry and rendering

- **Fills:** one indexed `ArrayMesh` per LOD built from the offline earcut triangulation of every polygon part with its holes.
  - Every part's triangulation is verified at build time (earcut `deviation` ≤ 1e-6; measured maximum 9.8e-10).
  - At test time, triangle area must equal outer rings minus holes for every region and LOD.
  - So lakes and enclave holes are real holes, and enclaves (25 at LOD3, e.g. Kota Bukittinggi in Agam) are not covered by the surrounding kabupaten.
- **Identity per vertex:** every vertex stores its region's entry index in `UV.x`. Entries 0–513 are the 514 kab/kota in registry (simulation) order; entries 514+ are the 21 BIG unallocated fragments (D-052), drawn grey and never selectable.
- **Colours:** `map_fill.gdshader` reads one texel per entry from a 1-pixel-high texture. `recolor()` rewrites 535 texels instead of about 730k vertex colours, and the result applies to every LOD at once.
- **Borders:** kab/kota and province outlines are indexed line meshes in a child node. They are hairlines, because GL lines have no width.
- **Hover and selection:**
  - Outlines are drawn around every ring of the region in the active LOD: all islands and holes.
  - The selection outline is 2.5 screen px wide and centred on the border, so it overlaps neighbours by about 1.25 px. This is the same style as before.
- **Regions are never merged:** a multipart region keeps all its parts under one entry index.

## 5. LOD selection

Thresholds come from the documented LOD view bands (`research/reports/lod_tolerance_selection.json`: LOD1 ≥ 2,000 km wide, LOD2 300–2,000 km, LOD3 < 300 km at a 1,600-px reference viewport). They are expressed as on-screen scale, so they are resolution independent:

| Scale (metres per screen pixel) | LOD |
|---|---|
| ≥ 1,250 | lod1 (national) |
| 187.5 – 1,250 | lod2 (regional/provincial) |
| < 187.5 | lod3 (kab/kota) |

- **Pure function of zoom:** the LOD depends only on scale. Panning never changes the LOD, and both zoom directions switch at the same scale (measured: in at 1,128 and 183 m/px, out at 203 and 1,252 m/px, with ×1.15 zoom steps).
- **No hysteresis:** zoom changes in discrete wheel steps and the function has no state, so there is no flapping to suppress. None was observed in the sweeps, and none was added.
- **Status:** `MapView.active_lod` and `lod_reason` hold the active LOD and why; the left panel shows "Detail peta: … (LODn) · 1 piksel ≈ …".
- **Loading:**
  - LOD1 loads synchronously at start (about 39 ms).
  - LOD2 and LOD3 are parsed on worker threads (`WorkerThreadPool`) starting right after the first frame. Their meshes are built on the main thread, taking 11 and 22 ms.
  - If a LOD is needed before its task finishes, the switch waits for that task instead of loading it a second time.
  - All loaded LODs stay cached: about 146 MB static and 113 MB video memory in total.
  - Measured without preloading, the first zoom into LOD3 stalled for about 105 ms; with preloading, the switch frame takes 5.6 ms.
- **Alignment:** all LODs share one projection and one entry order (checked at load). The national bounds of LOD2 and LOD3 agree with LOD1 within 1 km.

## 6. Interaction → canonical identity

- **Hit-test path:** `main._unhandled_input` → `MapView.region_at(world)` → `MapLod.entry_at` → `ids[i]`.
  - `ids[i]` is the Kemendagri `region_id`, never an array position or display label.
  - The region panel reads everything else from `ContentDB.region_by_id[id]`: name, kind, BPS code, parent province and its BPS code.
- **Hit test:**
  - A grid of region bounding boxes yields candidates.
  - Each candidate is then tested even-odd over all its rings (outer rings and holes of every part), using a crossing-number test with per-ring bounding boxes.
  - `Geometry2D.is_point_in_polygon` is **not** used. It was measured to misjudge metre-scale islet rings at these coordinates (ray to about 1e20 in float32). A regression test covers it.
- **Navigation:**
  - Click selects.
  - Esc or ✕ deselects.
  - "Lihat Provinsi <nama>" in the panel zooms to the province.
  - Home shows all of Indonesia.
  - Pan: right/middle-drag, trackpad pan, arrow keys, WASD (physical keys).
- **Fragments:** BIG unallocated fragments are never selectable.

## 7. Packaging (Windows export)

The `.bin` files are not Godot resources. **The export preset must include `data/map/v2/*.bin`** (Export → Resources → "Filters to export non-resource files", e.g. `*.bin, *.json`). No export preset or export template exists on the research machine yet, so a packaged build was not verified (see the report).

## 8. QA commands

```sh
# Godot tests (headless): 110 tests incl. 15 map tests
tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/run_tests.gd

# In-engine benchmark + 17 screenshots (windowed, real renderer)
tools/Godot.app/Contents/MacOS/Godot --path game -- --map-bench=<output dir>

# Manual QA checklist, automated (real input; isolated saves; moves the real cursor on macOS)
tools/Godot.app/Contents/MacOS/Godot --path game -- --qa-checklist=<output dir>

# Single screenshot of a view (game automation)
tools/Godot.app/Contents/MacOS/Godot --path game -- --screenshot=<png> --hide-case --view=<lon>,<lat>,<m_per_px> [--select=<region_id>]
#   gameplay: [--decide=<choice>] [--quarters=N] [--overlay=<id>] [--change] [--log]  (docs/31)
```
