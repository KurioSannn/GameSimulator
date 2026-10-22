#!/bin/bash
# Rebuild all derived data from raw captures (no network unless raw files are missing).
set -euo pipefail
cd "$(dirname "$0")/.."
PY=.venv/bin/python
$PY scripts/pipelines/geo/build_region_registry.py
$PY scripts/pipelines/geo/ingest_big_area.py
$PY scripts/pipelines/hazard/ingest_irbi.py
$PY scripts/pipelines/hazard/ingest_bnpb_events.py
$PY scripts/pipelines/hazard/index_bnpb_years.py
$PY scripts/pipelines/bps/ingest_bps_table_pages.py   # population (2026 projection) + IPM 2024 from BPS table pages
# Add connectors' parse steps here as sources become available (see research/data/VARIABLE_INVENTORY.md).
$PY scripts/pipelines/calibration/build_baseline.py
$PY scripts/pipelines/calibration/compare_flood_frequency.py
$PY scripts/pipelines/calibration/build_hazard_calibration.py
$PY scripts/pipelines/calibration/build_budget.py
$PY scripts/pipelines/game/export_game_data.py
$PY scripts/validate_all.py
