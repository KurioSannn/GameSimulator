# TECHNICAL DESIGN (living document)

Status: v0.1, 2026-10-05. Owner: Claude Code (proposal); approval: Galih.
This describes what is **actually implemented**, plus the planned next layers, marked as such.

## 1. Toolchain

| Item | Choice | Why |
|---|---|---|
| Engine | **Godot 4.7.2-stable** (latest stable, released 2026-08-18) | Current stable; typed GDScript; `Logger` API for test harness; mature Windows/Android export |
| Language | GDScript, typed | Project constraint; no C#/.NET, so export needs no extra runtime ("tanpa instalasi software tambahan") |
| Renderer | **Compatibility (OpenGL 3.3 / GLES3)** | 2D-only game; widest Windows GPU/driver coverage, including old laptops judges may use; same renderer on Android, so the APK pass is not a renderer migration |
| Research pipelines | Python 3 + `.venv` (`requirements.txt`: requests, jsonschema) | Data engineering outside the game runtime |
| GIS processing | mapshaper 0.7.x (npm, local in `tools/node`) | Topology-preserving simplification; no system GDAL needed |
| Tests | Custom headless runner `game/tests/run_tests.gd` | No third-party addon dependency; fails on any engine/script error via `OS.add_logger` |

Local toolchain lives in `tools/` (gitignored). To reproduce: download `Godot_v4.7.2-stable_<os>` from the official GitHub release into `tools/`; `cd tools/node && npm install --cache ../npm-cache mapshaper`.

## 2. Layering

```text
research/ + data/raw ──(python pipelines)──► data/normalized ──(export)──► game/data/*.json   [build time]
                                                                              │
Godot runtime:                                                                ▼
  ContentDB (autoload, read-only content)  ──►  WorldFactory  ──►  SimWorld (authoritative state)
  Game (autoload, app flow) ── owns ──► Simulation (systems), CaseEngine, SaveService
  UI / Map (scenes)  ── read SimWorld, call Game methods, listen to signals ──  never own state
```

- Runtime never parses raw/research data and never uses the network.
- `src/sim/*` has **no Node/scene dependencies**: it is plain `RefCounted` classes, so it is unit-testable headless and Android-portable unchanged.

## 3. Simulation core (implemented; exact v0.3 equations in research/reports/2026-10-05_MILESTONE2_CASE0001_VERTICAL_SLICE.md §2)

- **Simulation entities: the 514 kabupaten/kota.** Provinces (38) and the nation are aggregates computed from them. Province-level-only data is stored with `resolution = provinsi` and never copied into kab/kota fields as if it were kab/kota data.
- **SimWorld** stores regional state structure-of-arrays: `vars[name] -> PackedFloat64Array(514)`. There are no per-region Nodes and no per-region `_process`.
- **Monthly tick** (`Simulation.step_month`) runs in a fixed order, each step a tight loop over **all** regions:
  1. apply due effects (`EffectQueue`)
  1a. budget (spending level → fiscal space; sector intensities → capacities; D-027)
  1b. recurring floods (season × exposure → occurrence; severity × (1 − 0.75 × protection) → damage; counter RNG, D-025/D-026)
  2. recovery and logistics (damage decays faster with infrastructure and services; logistics derives from infrastructure and damage)
  3. food and prices (two passes: local realized supply, then national pool and logistics-gated trade, then price)
  4. welfare (converges to `welfare_base`, adjusted for price pressure, damage and services)
  5. sentiment and trust (target = `sentiment_base` + signed deviation terms for welfare vs `welfare_base`, price vs 100, trust, environment and damage; an unshocked world is an exact equilibrium, which tests enforce; trust is slow memory of sentiment)
- **Quarterly turn** = 3 ticks; **term** = 60 ticks (`SimWorld.TERM_TICKS`).
- **Coefficients** live in `game/data/sim_params.json`. They are labeled `DERIVED` design assumptions with a stated intent each; none are real statistics.
- **Determinism**: a seeded `RandomNumberGenerator` lives in SimWorld, and its state is saved as a string (64-bit safe). Tests assert bit-identical results for the same seed and inputs, and after a save/load round trip.
- **Measured** (M1 Pro, headless, 2026-10-05, after the v0.2 sentiment model): 514 regions → **2.5 ms per tick median**, 60-tick term in 149 ms; 5,140 regions (10× stress) → 25 ms per tick. In-game quarter (3 ticks + UI refresh + recolour) took 12.8 ms. The per-region driver dict in `sentiment_components` is the main cost and can be inlined if needed. Windows target hardware still needs to be measured.

## 4. Effects and cases (implemented)

- An effect is a plain dict: `{scope, var, op(add|mul|set), value, delay, duration}`. Scopes: `national | all | region:<id> | regions:<id,id> | province:<code>`. Values are clamped to the variable bounds declared in `sim_params.json`.
- **CaseEngine** evaluates a JSON condition DSL (`all/any/not`, `tick`, `var`+`agg`, `national`, `memory`, `case_seen`, `case_choice`). It picks by story-priority tier, then weighted random using the world RNG, so selection is deterministic and replayable. A choice schedules effects and writes `memory` flags that later conditions read. That is how branching works (Case A → choice → memory flag → Case B or C becomes eligible).
- A game case (`game/data/cases/`) must reference a research record (`research/cases/`). Validation enforces that every real-context line cites sources declared in that record, and that all choices are labeled `SIMULATED`.

## 4b. Session (implemented)

`src/sim/session.gd` holds the playthrough flow (present case → decide → advance quarter → next case) with no autoload dependency; `Game` wraps it. The gold-standard suite `tests/test_case_0001.gd` plays full five-year terms through Session and compares against `tests/golden/case0001.json`.

## 5. Save system (implemented)

- One JSON file per slot in `user://saves/` with no slot cap. Floats are encoded exactly (`SaveCodec`, D-028): Godot JSON is lossy for about 9% of doubles. Quicksave uses slot `quicksave`; autosave rotates across 3 slots at each quarter boundary.
- Envelope: `{format, envelope_version, meta, payload_json, sha256}`. The checksum covers the exact payload string.
- Writes are atomic: `.tmp`, then the previous file becomes `.bak`, then a rename. `load_with_recovery` falls back to `.bak`.
- Corrupt, tampered, newer-version or different-region-snapshot saves are rejected with a Bahasa message and never crash; other slots are untouched.
- Save size: 86 KB for 514 regions; serializing takes 1.4 ms.
- Migration: `envelope_version` and `SimWorld.SAVE_SCHEMA` are separate. Migrations will be functions `migrate_vN_to_vN+1(payload)` applied in sequence (none exist yet).

## 6. Data/provenance model (implemented, partially populated)

Pipeline (`scripts/run_pipeline.sh`): connectors/ingesters → `data/normalized/observations/<var>.jsonl` (schema-validated REAL rows) → `pipelines/calibration/build_baseline.py` (rules in `data/calibration/variable_map.json`) → `game/data/baseline.json` (values, per-region `region_status`, provenance) + `export_game_data.py` → `game/data/regions.json` (REAL reference facts per region). Coverage report: `research/reports/validation/calibration_coverage.md`. Tests: `.venv/bin/python -m unittest discover -s scripts/tests`.


- Region registry key: the Kemendagri code (`PP` / `PP.KK`), as published by BIG in `kdpkab`. Names are labels only.
- `game/data/baseline.json`: for each variable, `status ∈ {REAL_OFFICIAL, DERIVED, UNCALIBRATED}`, plus values, provenance and reference_period. **Every variable is currently `UNCALIBRATED`.** Neutral defaults are used and the UI must show "belum terkalibrasi", never a number styled as a statistic.
- Schemas: `data/schemas/*.schema.json`. Validator: `.venv/bin/python scripts/validate_all.py`.

## 7. Map (implemented v0)

- Raw: BIG full-resolution GeoJSON per feature (gitignored, checksummed manifest).
- Derived (superseded 2026-10-22, see docs/30_MAP_INTEGRATION.md and D-058): geography v2 render LODs (Douglas–Peucker 1,000/100/40 m, BIG edisi Juni 2026) → projected (equirectangular, lon0 118°E, standard parallel 2.5°S, 100 units/degree) and earcut-triangulated meshes in `game/data/map/v2/kabkota_lod{1,2,3}.{json,bin}`. Provenance, projection and triangulation checks are recorded in each metadata file.
- Rendering: one fill `ArrayMesh` (triangulated, per-vertex colour; `MapView._draw`) and one border line mesh, built once with per-vertex region colours rewritten on overlay change. No Node per region. Borders are a separate line mesh. Disputed/uncoded BIG areas render neutral and are not selectable.
- Holes are not cut; draw order is largest-first and hit priority smallest-area-first, so enclaved kota render and select correctly. lod0: 104,959 vertices, loads in ~127 ms.
- Hit testing: a per-region AABB grid index, then `Geometry2D.is_point_in_polygon` on candidates only.
- Input: wheel zoom to the cursor; middle- or right-drag to pan; left click selects; hover shows a tooltip.

## 8. Rejected alternatives

| Alternative | Why rejected |
|---|---|
| One Node per region with `_process` | Violates docs/10 §8; poor scaling; couples simulation to the scene tree |
| `.tres` Resources for 514-region state | Heavy for bulk numeric state and slower to serialize; Resources remain an option for hand-authored UI/config |
| SQLite addon | Third-party native dependency on two export targets; JSON is enough at this data size |
| Forward+/Mobile renderer | No benefit for 2D; worse old-hardware compatibility |
| GUT/gdUnit | Adds a dependency; a 60-line runner covers our needs |
| Godot `Expression` for case conditions | Arbitrary code in content, harder to validate; the JSON DSL is schema-checkable |

## 9. Commands

```bash
G=tools/Godot.app/Contents/MacOS/Godot           # macOS dev; Windows: tools/Godot_v4.7.2-stable_win64.exe
$G --headless --path game --import                # first run / after adding class_name scripts
$G --headless --path game -s res://tests/run_tests.gd
$G --headless --path game -s res://tests/bench_tick.gd
.venv/bin/python scripts/validate_all.py
python3 scripts/pipelines/geo/fetch_big_kabkota.py
python3 scripts/pipelines/geo/build_region_registry.py
python3 scripts/pipelines/game/export_game_data.py
```

## 10. Desktop UI (implemented v0, prototype styling)

`src/app/main.gd` wires: top bar (Level 1 national indicators + uncalibrated warning), overlay selector and legend, `RegionPanel` (Levels 2–3, with fact-class tags and a sentiment driver explanation), `CaseModal` (FAKTA NYATA → NARASI FIKSI → PILIHAN/SIMULASI), hover tooltip, and turn/save controls. UI is built in code with `UiKit`; to be replaced by a Theme from Figma (Cleo).

QA automation: `Godot --path game -- --screenshot=out.png [--decide=a] [--quarters=N] [--select=31.71] [--overlay=damage]` renders the real window and saves a PNG.

## 11. Policy and budget (implemented v0, D-039–D-041)

- `src/sim/policy_engine.gd`: generic engine over `game/data/policies/*.json` (schema `data/schemas/policy.schema.json`). Effects are scheduled at enactment with explicit region lists through `EffectQueue`, and every region still runs through the monthly simulation.
- `EffectQueue` per-region response `scale_by` (capacity/gap); runtime scope cache `SimWorld.scope_cache` (not saved).
- `src/sim/conditions.gd`: shared condition DSL (cases + policies; `policy_active`, `policy_enacted`).
- Budget: commitments crowd out sector intensities; `Simulation.fiscal_report()` gives the monthly ledger in FU. The contract is in `data/calibration/fiscal_structure.json`.
- UI: `src/ui/policy_panel.gd` (P); budget panel shows the ledger.
- Save schema v3 (`policy_state`), with v2 → v3 migration.
- Tests: `docs/TESTING.md`.
