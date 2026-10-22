# Research pipeline (out-of-game)

Offline research tooling. None of this runs inside the Godot build. The game ships only derived, packaged data (CLAUDE.md: offline-first).

## Requirements

- Python 3.10+, standard library only.
- Node.js 18+ with the project-local mapshaper, pinned to 0.7.79 and installed without touching global npm settings:

```sh
npm ci --prefix tools/geo --cache tools/geo/.npm-cache --no-audit --no-fund
```

## Reproduce the geography baseline (SNAP-2026-10-21)

Run from the repository root.

**1. Raw capture.** Cached and immutable; a re-run reuses existing files.

```sh
python3 scripts/pipelines/geo/v2/fetch_bps_bridging.py                       # SRC-0002
python3 scripts/pipelines/geo/v2/fetch_big_boundaries.py --no-geometry       # SRC-0001 + SRC-0005 attributes
python3 scripts/pipelines/geo/v2/fetch_big_boundaries.py --source SRC-0001   # full-res polygons, ~2.2 GB
python3 scripts/pipelines/geo/v2/fetch_big_boundaries.py --recover-oid 3424  # Sumbawa recovery copy (D-056)
python3 scripts/pipelines/geo/v2/fetch_big_boundaries.py --source SRC-0007   # province boundary lines
python3 scripts/pipelines/geo/v2/fetch_bps_area_tables.py                    # SRC-0008 (2025)
python3 scripts/pipelines/geo/v2/fetch_bps_area_tables.py --only yogyakarta
python3 scripts/pipelines/geo/v2/fetch_bps_area_tables.py --year 2024 --only aceh sumut jakarta maluku papuabarat
python3 scripts/pipelines/geo/v2/check_big_geometry.py                       # completeness and integrity
```

**2. Registry and area audit.**

```sh
python3 scripts/pipelines/geo/v2/build_region_registry.py
python3 scripts/pipelines/geo/v2/audit_area_units.py
python3 scripts/pipelines/geo/v2/compute_source_adjacency.py                 # adjacency reference for validation
```

**3. Render LODs.** Douglas–Peucker, intervals per D-053.

```sh
python3 scripts/pipelines/geo/v2/build_render_geometry.py --lod lod1 --interval 1000
python3 scripts/pipelines/geo/v2/build_render_geometry.py --lod lod2 --interval 100
python3 scripts/pipelines/geo/v2/build_render_geometry.py --lod lod3 --interval 40
R=data/processed/geography/SNAP-2026-10-21/render
python3 scripts/pipelines/geo/v2/validate_render_geometry.py $R/lod1 $R/lod2 $R/lod3
python3 scripts/pipelines/geo/v2/audit_island_components.py
python3 scripts/pipelines/geo/v2/compare_province_lines.py $R/lod3
python3 scripts/pipelines/geo/v2/render_previews.py                          # macOS (uses qlmanage)
python3 scripts/pipelines/geo/v2/measure_load_times.py
```

**4. Tests.**

```sh
python3 -m unittest discover -s scripts/pipelines/geo/v2/tests -v
```

`--snapshot SNAP-YYYY-MM-DD` selects a different raw snapshot folder.

## Contracts

- **Raw captures** go to `data/raw/<SRC-id>/<SNAP-id>/<file>` with a `<file>.meta.json` sidecar (url, retrieved_at, sha256). Raw files are never overwritten. To refresh, use a new snapshot ID.
- **Every request attempt** is appended to `data/catalog/source_access_log.csv`, including retries and failures.
- **Request pacing:** at least 1 s between requests, exponential backoff, at most 4 attempts.
- **Builders** embed input SHA-256s or exact commands in their outputs. The tests verify that raw files still match their sidecars.

## Storage note

The full-resolution BIG polygon pages (about 2.2 GB) are excluded from Git (D-057, `.gitignore`). Their sidecars and the access log are committed, so each page can be re-fetched and verified by SHA-256.

The test suite verifies every raw file against its sidecar, so it needs the local raw store. After a fresh clone, re-run the SRC-0001 capture commands above first. The pages are re-fetched and must reproduce the recorded SHA-256 values; if BIG has changed them, capture into a new snapshot ID instead.
