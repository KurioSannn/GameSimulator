# Baseline calibration pass: execution report (2026-10-23)

## Attempted
Replace neutral starting values with official data for every simulation variable that has it; label the rest accurately.

## Succeeded
- **BPS table pages embed their full data cube.** Two national tables were ingested without the API key (`scripts/pipelines/bps/ingest_bps_table_pages.py`; raw pages and sha256 sidecars in `data/raw/bps/tables/`):
  - **Population** (var 2790, 2026 projection based on SP2020, updated 2026-08-28): 514/514 kab/kota and 36/38 provinces. The national kab/kota sum is 287,198,383.
  - **IPM metode baru** (var 413, 2024, updated 2025-05-15): 514/514 kab/kota and 38 provinces. Range 36.30 (Nduga) to 88.77; Indonesia 74.20.
- **Baseline status:**

  | Status | Count | Variables |
  |---|---|---|
  | REAL_OFFICIAL | 3 | population, welfare_base, welfare |
  | DERIVED | 2 | flood frequency and risk profile (unchanged) |
  | BY_DESIGN | 10 | model states, each with a reason |
  | UNCALIBRATED | 5 | food_capacity, infrastructure, logistics, services, environment |

- **Game:**
  - national indicators are population-weighted;
  - region panels show population and IPM as sourced facts;
  - the welfare map is no longer hatched;
  - the top-bar warning names the 5 remaining variables.
- **Follow-up thresholds:** CASE-0003-A / CASE-0004-A now trigger at the province's calibrated start − 1 (72.5 and 71.4, previously 54).

## Failed / conflicting
- **BPS province population rows for Papua and Papua Barat:** inconsistent with their kab/kota sums. Dropped and logged (G-38).
- **Road condition:** BPS publishes it only on per-province sites with mixed years. No national kab/kota table was found, so infrastructure stays uncalibrated (G-39).

## Checks
| Check | Result |
|---|---|
| Godot tests | 140/140 |
| Assumption updates | Six tests that hard-coded the old flat start (welfare 55, equal weighting, a "high welfare" fixture of 60) now use the calibrated starts |
| Golden masters | All 8 regenerated: values only. Follow-up sequences unchanged; the full-game schedule is identical |
| Pipeline | 28/28 |
| Geography v2 | 44/44 |
| `validate_all` | OK |

## Not calibratable from data
- **Sentiment and trust:** no official kab/kota measure of support for a fictional president exists, and proxies risk stereotyping. They are labeled as model states.

## Next action
- Ingest infrastructure from per-province road tables (or PUPR) with a documented year rule.
- Services from Podes 2024 facilities.
- Environment from KLHK IKLH.
- Food capacity from staple production (rice, maize, sago), with a rule that does not mark sago or maize regions as deficient.
