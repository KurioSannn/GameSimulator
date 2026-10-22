# Execution report: G-15 multi-year index, G-16 consistency, BPS workflow

Date: 2026-10-06 · Agent: Claude Code

## Deliverable summary (as requested)
| # | Item | Result |
|---|---|---|
| 1 | BNPB years indexed | **26/26** (2000–2025) via the BNPB Satu Data portal API: `research/sources/bnpb_yearly_index.{md,json}` |
| 2 | BNPB years downloaded (kab/kota) | **1** (2024, DataStore API). 2000 and 2001 are API-available but excluded from frequency (pre-2002 boundaries, pre-BNPB recording); 2025 is province level only |
| 3 | BNPB years blocked (manual access) | **22** (2002–2023): `MANUAL_DOWNLOAD_REQUIRED`. Google Drive folders whose download endpoints robots.txt disallows. Exact folder URLs and destinations listed |
| 4 | Real region-year observations | 450 kab/kota × 1 year × 10 flood measures = **4,500** BNPB rows. Plus IRBI 1,028 rows and area 514 rows, for **6,042** REAL observations in total |
| 5 | Multi-year frequency statistics | **Not available**: one year only. Comparison report generated and states this; production model unchanged (2024, pinned) |
| 6 | BPS indicators ingested | **0**: no API key. Workflow ready and gated |
| 7 | Calibrated simulation variables | **2** (`flood_frequency`, `flood_risk_profile`), unchanged |
| 8 | Severity calibration | **Not recalibrated** (population not available), per instruction |
| 9 | Tests | Godot **49/49**, pipeline **22/22** (+4: BPS gate ×3, pinned years ×1), schema validation OK |
| 10 | Benchmark (3 runs, M1 Pro) | reference 3.41–3.45 ms per tick median (p95 3.8), worst case 4.39–4.41 ms (p95 6.4–6.5), load ≈ 5 ms, case evaluation < 0.07 ms. First save per process ≈ 21–24 ms, later ≈ 5 ms |
| 11 | Remaining gaps | see below |

## G-15: year-by-year registry
- Status per year: 2000 and 2001 `API_AVAILABLE`; 2002–2023 `MANUAL_DOWNLOAD_REQUIRED` (2014 has 2 Drive resources); 2024 `API_AVAILABLE` (28 DataStore tables); 2025 `API_AVAILABLE` (province level, 10 tables).
- Every entry records the dataset title, organization (BNPB Pusdatinkom), license, official dataset URL, resource titles, URLs and formats, DataStore availability and expected manual destination.
- `data/raw/bnpb/drive_manual/README.md` gives the manual procedure. Re-running `index_bnpb_years.py` detects placed files, records checksums, and marks the year `MANUAL_FILES_PRESENT`.
- **No parser** for the Drive files has been written: their real structure must be inspected first.

## Multi-year model safeguards (D-037)
- Production `flood_frequency` uses pinned years (`["2024"]`). Manually added years cannot leak into production; a unit test enforces this.
- `compare_flood_frequency.py` will report production vs candidate (mean, median, p90, max, regions observed, prior parameters, completeness, largest regional changes) once at least two years exist.
- Missing years are never counted as zero: the Gamma–Poisson rule uses observed years only.

## G-16 (kept, not reconciled)
`research/reports/validation/bnpb_2024_consistency.md`: events differ (kab/kota sum 1,428 vs national row 1,420, +8), while **all nine impact tables match their national rows exactly**. This pattern suggests that events spanning several kab/kota are counted per kab/kota, but that is unverified. Recorded as an unresolved source discrepancy in the gap registry and source metadata.

## BPS workflow (no key, nothing fabricated)
- `.env` confirmed gitignored (`git check-ignore`); `.env.example` added with an empty `BPS_API_KEY=`.
- `scripts/pipelines/bps/bps_workflow.py check | inventory | sample <indicator> | bulk`.
- Bulk ingestion **refuses** any indicator in `data/calibration/bps_indicators.json` that lacks a confirmed var_id, title, unit, year, level, region coding and domain scope, plus a manual `sample_checked`.
- All five priority indicators ship unconfirmed (tested). Var IDs come only from the live inventory.

## Remaining gaps
- **G-15 (human)**: download the 2002–2023 Drive folders.
- **G-01 (human)**: BPS API key.
- **G-13**: severity awaits population; seasonality awaits BMKG.
- **G-16**: unresolved source discrepancy.
- Data-model expansion beyond floods (budget/policy calibration) awaits APBN and BPS.
