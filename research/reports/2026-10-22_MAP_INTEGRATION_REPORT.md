# MAP INTEGRATION REPORT: geography v2 → Godot vertical slice (2026-10-22)

**Scope:** load the validated geography (BIG edisi Juni 2026, LOD1/2/3; D-053) into the existing Godot game as an offline, interactive desktop map that resolves selections to canonical Kemendagri IDs. Architecture and contracts are in `docs/30_MAP_INTEGRATION.md`.

## 1. What was done

- **Repository reconciliation.** The geography milestone had been built in a separate copy of the planning package (`~/Projects/…`, commit `b6790d1`). This repository is canonical, so it was imported first (commit `15db37d`; decisions renumbered D-050–D-057; docs/29).
- **Offline build** (`build_map_lods.py`):
  - projection, identical to the existing game projection, for all LODs;
  - earcut triangulation with holes, checked per part (max deviation 9.8e-10);
  - packaging into metadata JSON plus a binary file;
  - SHA-256 provenance back to the validated render LODs.
- **Runtime:**
  - `MapLod`: pure data, validation, hit testing.
  - `MapView` (rewritten in place, same public API): shader-coloured indexed meshes, border meshes, LOD by on-screen scale, worker-thread preload, outlines.
  - Region panel: Kemendagri ID, BPS code, parent province (+ its BPS code), "Lihat Provinsi" button.
- **Registry:** `kode_bps` added to `region_registry.json` and `game/data/regions.json` from the validated crosswalk (SRC-0002). A semantic diff showed nothing else changed except timestamps.
- **Retired:** `game/data/map/kabkota_lod0/lod1.json` (BIG 2023-09; it dropped islands under 2 and 25 km², and filled holes). `build_map_geometry.py` is marked superseded.

## 2. Defects found and fixed during integration

| Defect | Evidence | Fix |
|---|---|---|
| Godot `Geometry2D.is_point_in_polygon` reports a point inside a metre-scale islet ring that lies entirely to its right (ray to ~1e20 in float32). Even-odd then flipped, and 71 of 5,950 fixture points (tiny Wakatobi, Rote and Aru islets) resolved to no region. | Godot debug: ring x-range 599.1767–599.1819, point x = 599.1755, built-in returned `true` | Own crossing-number test with per-ring bounding boxes (`MapLod.point_in_ring`) + regression test. The previous renderer used the same built-in. |
| A new `class_name` that wasn't in the class cache made `main.gd` fail to parse. Every headless suite still passed (none loads `main.gd`), and the game sat idle with no screen. | first bench run hung; log showed the parse error | Import refresh + new test `test_every_game_script_parses` (loads every script under `res://src`) |
| First zoom into LOD3 stalled ~105 ms (LOD2 ~67 ms) while loading synchronously | baseline bench `map_bench_baseline_sync_load.json` | LOD2/LOD3 parsed on worker threads after the first frame (switch frame now 5.6 ms) |
| Preload started in `_ready` delayed the first frame by ~370 ms | intermediate bench | Preload starts on the first `frame_post_draw` |
| A malformed metadata file pushed an engine error (`JSON.parse_string`) in addition to the readable message | test runner counted the engine error | `JSON.new().parse()` (error code, no engine error) |

## 3. Automated tests (all actually run, 2026-10-22)

| Suite | Result | Notes |
|---|---|---|
| Godot headless (`run_tests.gd`) | **101/101 pass** | 87 existing + 14 new map tests; none skipped. The runner loads only the listed suites; `test_map.gd` was added to the list. |
| Pipeline Python (`scripts/tests`) | **28/28 pass** | 22 existing + 6 new (`test_map_lods.py`) |
| Geography v2 (`scripts/pipelines/geo/v2/tests`) | **44/44 pass** | unchanged geometry; raw sidecars verified |
| Schema validation (`validate_all.py`) | **clean** | |

The new Godot map tests cover:
- offline loading of each LOD from `res://`;
- 514 canonical IDs in registry order, with valid parents and BPS codes consistent with the province BPS code;
- every vertex and triangle belonging to exactly one region;
- triangle area equal to polygon area minus holes for every region and LOD;
- holes present;
- **15,630 independent fixture points** (5,950 in the first version, which listed region 96.05 as Raja Ampat although 96.05 is Maybrat; corrected to 96.03, so Raja Ampat's thousands of islets are now covered) (projection + packaging + hit test against Python point-in-polygon on the lon/lat source): extreme islands, every part of six multi-island regions, 50 enclave/surrounding points per LOD, true holes resolving to no region, and points 30 m either side of 40 shared borders per LOD;
- projection parity with the build;
- alignment of the LOD bounds;
- LOD thresholds equal to the documented bands, in both zoom directions;
- MapView LOD switching keeping identity and selection;
- background preload without double loading;
- readable errors for missing, malformed and truncated assets;
- the islet regression;
- every script parsing;
- no network APIs in the map code.

## 4. In-engine measurements (real Godot 4.7.2, windowed)

**Machine:**
- MacBookPro18,3, Apple M1 Pro (8 CPU threads), 16 GB RAM, macOS 26.2.
- Godot 4.7.2-stable, Compatibility renderer (OpenGL 4.1 on Metal).
- Display 3024×1964 Retina at 2× scale; game window 3024×1636 physical, viewport 1996×1080 logical (stretch `canvas_items`).
- Vsync disabled for the measurement; frame time = wall time between `frame_post_draw` signals.

**Data:** `research/reports/map_integration/map_bench_final.json` (final build) and `map_bench_baseline_sync_load.json` (before preloading).

| # | Measurement | Result |
|---|---|---|
| 1 | Cold startup: engine start → main screen `_ready` | 978 ms |
| 1 | LOD1 load at startup (parse + index + meshes) | 38.7 ms |
| 2 | LOD2 / LOD3 parse on worker thread; mesh build on main thread | 119 / 166 ms wall (contended); meshes 10.9 / 21.6 ms |
| 2 | LOD2 / LOD3 loaded synchronously (baseline) | 67 / 105 ms (read 6/12, meta 13/12, arrays 5/20, index 31/40, meshes 11/21) |
| 3 | First complete map frame (engine start →) | 1,174 ms; LOD2/LOD3 ready at 1,294 / 1,340 ms |
| 4 | Idle frame time, median / p95 / max | lod1 2.51 / 5.86 / 46.2 (one isolated frame) · lod2 2.92 / 4.79 / 6.6 · lod3 3.97 / 5.22 / 8.0 ms |
| 5 | Panning frame time, median / p95 / max | lod1 2.47 / 4.39 / 5.3 · lod2 3.00 / 4.22 / 11.2 · lod3 3.78 / 5.04 / 6.1 ms |
| 5 | Zooming (×1.15 per frame, national → LOD3), first time after start | non-transition frames median 3.64, p95 8.05, max 9.5 ms |
| 5 | Zooming, warm | median 3.5, p95 4.9–5.8 ms |
| 6 | Hover handler (hit test + highlight + tooltip), 500 samples at LOD3 | median 0.14, p95 0.28, max 0.52 ms; hit test alone 0.13 / 0.25 ms |
| 6 | Click handler (select + region panel build) | median 5.5, max 6.1 ms; click → next drawn frame median 13.6, max 23.2 ms |
| 7 | Memory, LOD1 only → all LODs | static 66 → 146 MB; video 54 → 113 MB; buffers 12 → 71 MB |
| 8 | LOD transition frames, zoom in, first time | lod1→lod2 4.67 ms at 1,128 m/px; lod2→lod3 5.64 ms at 183 m/px |
| 8 | LOD transition frames, zoom out | lod3→lod2 3.06 ms at 203 m/px; lod2→lod1 2.48 ms at 1,252 m/px |
| 8 | Baseline (no preload): first switch into LOD3 | stalled ≈ 105 ms |

Notes:
- Render CPU time per frame (RenderingServer) is about 0.4 ms at every LOD.
- **GPU time is not measurable** on this Compatibility/Metal path: the API returns 0. It is not reported as 0 ms.
- The map is **not benchmarked on Windows**, the primary target, because no Windows machine or export is available (§7).

## 5. Visual verification (in-engine screenshots)

Files are in `research/reports/map_integration/screenshots/`, downscaled to 1,600 px wide. Shots 09–13 use a QA colouring with a distinct colour per region, because the gameplay overlays are uniform at game start.

| Shot | Checked | Result |
|---|---|---|
| 01 national (LOD1) | whole archipelago, all kab/kota outlined, PNG border at 141°E straight | ok |
| 02 Jawa Timur–Bali (LOD2) | provincial view, islands present | ok |
| 03 Jabodetabek (LOD3) | dense kab/kota borders, harbour piers, coastline | ok |
| 04 Raja Ampat (LOD3) | island-rich area, many small islands | ok, no clipped islands |
| 05 / 09 Bukittinggi in Agam (LOD3) | enclave hole: distinct colour, no overlap or seam | ok |
| 06 / 10 Muna (LOD3; 10 at 4 m/px, closer than gameplay maximum zoom) | true holes show background, not filled | ok |
| 07 selected Kota Bukittinggi + panel | yellow outline on the enclave only; panel shows "Kode Kemendagri 13.75 · Kode BPS 1375 · Provinsi 13 (BPS 13)" and "Lihat Provinsi Sumatera Barat" | ok |
| 08a–d threshold pairs (1,300/1,200 and 190/185 m/px, same centre) | LOD changes, geography stays aligned, no jump | ok |
| 11 Kota Bogor in Kab. Bogor (LOD3) | second enclave | ok |
| 12 Jabodetabek QA colours | neighbouring regions, no seams or gaps | ok |
| 13 Kepulauan Seribu | multipart small-island region | ok |

Other observations:
- **Flicker:** none observed in the sweeps. It can't be proven from stills; the sweep frame data shows no oscillating LOD.
- **Province borders:** drawn as darker hairlines. They coincide with kab/kota borders by construction (dissolved from the same layer).
- **Region panel clipping:** some rows are clipped at the panel's right edge, e.g. long reference-fact tags and the sentiment explanation. The **same clipping exists before this change** (shot `00_before_integration_panel_1375.png`, rendered from commit `15db37d`), so it is an existing UI issue, out of scope here.

## 6. Interaction to canonical identity

- **Hover, click and selection** all return `MapLod.ids[entry]`, which is the Kemendagri `region_id`. The panel reads name, kind, BPS code and parent province from the registry (`ContentDB`), never from geometry.
- **Multipart regions:** every disconnected part resolves to the same ID (fixture: all parts of six island regions).
- **Enclaves:** a point in an enclave resolves to the enclave, not to the surrounding kabupaten.
- **Fragments:** BIG unallocated fragments are not selectable.
- **No special cases:** no per-region scripts exist.

## 7. Limitations and blockers

1. **Windows not verified (blocker for the primary target).**
   - No Windows machine, no export preset, and no export templates are installed on this machine.
   - All measurements are macOS, M1 Pro, Compatibility renderer.
   - The export preset must include `data/map/v2/*.bin` as non-resource files (docs/30 §7). This is untested.
2. **First-draw spikes:** the first zoom after start still shows frame spikes up to about 9.5 ms (p95 8 ms), against about 5.8 ms warm. One isolated 46 ms frame was recorded at LOD1 idle. Not investigated further, since both are within budget at 60 Hz except that single frame.
3. **Memory:** all three LODs stay cached (146 MB static, 113 MB video). Unloading inactive LODs was not needed at this size and was not implemented.
4. **Distortion:** the equirectangular projection is visual only, with up to +1.8 % east–west stretch at 11°S.
5. **Holes at LOD1:** small Sulawesi Tenggara water holes collapse at LOD1, as already recorded in the geometry validation. They exist at LOD2/LOD3.
6. **Selection outline:** 2.5 px wide and centred on the border, so it overlaps neighbours by about 1.25 px. Unchanged style.
7. **Window size:** the window opens maximised at whatever the display allows (here 3024×1636 physical). The 1920×1080 project viewport is the stretch base, not the measured size.
8. **Region panel clipping:** existing UI limitation, see §5.

## 8. Manual QA checklist, automated (2026-10-22)

The team's manual checklist was run in the real engine with `-- --qa-checklist=<dir>` (`game/src/app/qa_checklist.gd`):
- keys go through `Input.parse_input_event`, mouse events through `Viewport.push_input`;
- saves go to an isolated `user://qa_checklist_saves`, never the player's slots;
- an error logger is attached for the whole run.

**Result: 6/6 items, 80/80 checks, 0 runtime errors.**

| Item | Checks |
|---|---|
| CASE-0001 | shown at start; key 1 decides it; modal closes; map visible |
| Map navigation | Home shows all of Indonesia (LOD1); wheel zoom in passes LOD1 → LOD2 → LOD3; zoom out passes LOD3 → LOD2 → LOD1; status label matches |
| Region selection | 16 regions in Sumatera, Jawa, Kalimantan and Papua: hover tooltip, click selects the canonical ID, panel shows name, Kemendagri ID, BPS code and province |
| Small islands | 9 regions in Maluku, Nusa Tenggara and island groups (incl. Kep. Seribu, Wakatobi, Raja Ampat): every clicked islet selects its own region; clicking the sea next to it selects nothing |
| Panel and movement | "Lihat Provinsi" frames the whole province; Esc deselects; right/middle-drag, trackpad pan and pinch, arrow keys, and **WASD** move the map |
| Gameplay and save | Space advances one quarter; F5 writes a valid (checksummed) quicksave; after another quarter, F9 restores the exact saved simulation state (identical world hash); 514 regions intact |

Findings:
- **WASD did not pan** (movement 0 for each key; the camera read only the arrow-key `ui_*` actions, although its comment promised WASD). Fixed in `map_camera.gd`: physical W/A/S/D keys, layout independent, ignored with Ctrl/Cmd so Ctrl+S still saves.
- **Mouse injection:** on macOS the game reads the real cursor position, so injected mouse positions did not reach the hover code. The run fell back to `Input.warp_mouse`, which **moves the real cursor while it runs**. This is recorded in the report (`mouse_injection: warp_mouse`).
- **Fixture correction:** the Raja Ampat code (above).

## 9. Reproduce

See `docs/30_MAP_INTEGRATION.md` §1 and §8.
