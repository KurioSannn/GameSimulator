# Execution report: first real simulation calibration (BNPB IRBI 2024 → flood exposure)

Date: 2026-10-06 · Agent: Claude Code

## What was attempted
Government hosts became reachable from this machine from 2026-10-05 ~19:30 UTC (probe log). BPS still needs a key (none provided), so I took the highest-value keyless official source for the current model: BNPB's IRBI, to replace case-evidence flood exposure (G-11 data side).

## What succeeded
- **Source**: "Buku IRBI 2024" PDF, hosted by BNPB on inarisk.bnpb.go.id (linked from the official IRBI page). Archived with a checksum (`data/raw/bnpb/irbi_2024/MANIFEST.json`; PDF gitignored for size). IRBI 2025 exists only as an online flipbook whose simplified HTML carries no usable tables, so **2024 is the latest edition with extractable data**. A truncated first download was deleted, never archived.
- **Rejected access paths**: InaRISK's internal POST endpoint returning HTML fragments (undocumented, would be scraping); BNPB ArcGIS REST (HTTP 521, origin down); data.go.id (no documented API found).
- **Parsed (text layer, no OCR)**: multi-hazard IRBI for 514/514 kab/kota (`irbi_total`); flood risk index for 397 kab/kota (`irbi_flood`), plus 117 explicit `NOT_PUBLISHED` rows.
  - Row numbers 1–397 are complete; every non-row line is a header or page number.
  - Spot checks match the PDF text exactly.
- **Name matching**: all rows matched to Kemendagri codes. Documented aliases cover the letter-spaced "P A P U A" text layer, DKI kota listed without the "KOTA" prefix, and two former regency names (Mamuju Utara → Pasangkayu 76.01; Maluku Tenggara Barat → Kepulauan Tanimbar 81.03; codes unchanged).
- **Calibration**: `flood_exposure` = 100 × IRBI flood score / 36 → **DERIVED for 397/514 regions** (first real-data-driven simulation variable). CASE-0001 no longer sets exposure itself.
- **Semantics fix**: the IRBI score is a *risk* index that already includes regional capacity, so `flood_protection` now starts at 0 and means *additional* protection built during the term. Starting at a neutral 20 would double-count capacity.
- **UI**: IRBI multi-hazard and flood risk are shown as REAL reference facts (1,425 facts in total). Exposure shows "AWAL: DATA 2024", with source details in a tooltip.

## Problem found → fixed
With real exposure, 397 regions became flood-prone. The old severity (U(10,40) × exposure, tuned for 7 regions) made **an untouched term drop national sentiment 55 → 36 (232 regions < 40)**. Every ordinary flood was as damaging as the scripted record 2020 Jakarta event.

Fix (D-031): exponential severity with mean 4 and cap 40, independent of exposure. Exposure now sets frequency only, which is what the IRBI ranking speaks to. Same 2,057 flood events (paired RNG).

National impact after the fix, untouched term:

| tick | month | regions flooded | mean damage | max damage | national welfare | national sentiment | regions <40 sentiment |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 6 | 6 | 9 | 1.46 | 18.0 | 54.50 | 54.15 | 0 |
| 12 | 12 | 73 | 2.15 | 22.1 | 53.94 | 53.45 | 0 |
| 18 | 6 | 10 | 2.65 | 24.4 | 53.32 | 52.22 | 3 |
| 24 | 12 | 70 | 2.61 | 27.6 | 53.29 | 51.84 | 4 |
| 30 | 6 | 7 | 2.91 | 21.4 | 53.00 | 51.09 | 5 |
| 36 | 12 | 53 | 2.85 | 31.4 | 53.09 | 50.94 | 5 |
| 42 | 6 | 11 | 2.97 | 21.6 | 52.91 | 50.39 | 9 |
| 48 | 12 | 65 | 2.78 | 19.5 | 53.09 | 50.46 | 7 |
| 54 | 6 | 6 | 2.94 | 20.2 | 52.92 | 49.99 | 11 |
| 60 | 12 | 63 | 2.74 | 21.1 | 53.09 | 50.08 | 10 |
total regional flood events over term: 2057 (1.04 per exposed region per year)

## CASE-0001 outcome matrix after real exposure (seed 11)
| CASE-0001 | recurring (R) | budget | flood events (7 regions) | cum. flood damage | end protection | end welfare | end sentiment (focus) | min sentiment (Jkt Pusat) | fiscal space | national sentiment | cases seen |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| a | a | baseline | 24 | 105.2 | 0.0 | 54.1 | 50.3 | 47.7 | 45.0 | 50.08 | 3 |
| a | b | baseline | 24 | 101.6 | 15.0 | 54.0 | 50.1 | 47.7 | 43.0 | 50.17 | 3 |
| a | c | baseline | 24 | 103.5 | 6.0 | 53.9 | 50.3 | 47.7 | 46.5 | 50.39 | 3 |
| b | a | baseline | 24 | 105.2 | 0.0 | 54.2 | 49.6 | 42.2 | 40.0 | 50.72 | 3 |
| b | b | baseline | 24 | 101.6 | 15.0 | 54.1 | 49.3 | 42.2 | 38.0 | 50.81 | 3 |
| b | c | baseline | 24 | 103.5 | 6.0 | 54.1 | 49.6 | 42.2 | 41.5 | 51.03 | 3 |
| c | a | baseline | 24 | 83.6 | 27.1 | 53.7 | 48.3 | 38.5 | 38.0 | 50.70 | 3 |
| c | b | baseline | 24 | 80.1 | 42.1 | 53.6 | 48.0 | 38.5 | 36.0 | 50.79 | 3 |
| c | c | baseline | 24 | 81.9 | 33.1 | 53.6 | 48.3 | 38.5 | 39.5 | 51.01 | 3 |
| c | b | +5% kebencanaan | 24 | 72.8 | 58.0 | 53.0 | 48.4 | 39.8 | 36.0 | 50.66 | 3 |
| a | a | +5% kebencanaan | 24 | 97.9 | 15.8 | 53.4 | 50.5 | 48.4 | 45.0 | 49.96 | 3 |

Reading:
- Mitigation still cuts focus-region flood damage by 20–30% for identical events.
- The recurring crisis now fires once per run (floods are smaller on average).
- The flood-control path now ends with *lower* Jakarta sentiment than relief (trust cost > smaller damage savings): resilience vs popularity.
- This feeds the planned legacy evaluation; a balancing question for playtests.

## Tests
- Godot **39/39**. New: `test_real_baseline_drives_hazard_drift` (397 exposed regions; real hazards produce damage; unlisted region stays undamaged).
- Controls moved to Kota Denpasar (exposure 0); core-model equilibrium tests now run explicitly hazard-free.
- Golden master regenerated (reason: real IRBI exposure + exponential severity).
- Python 14/14. Schema validation OK (incl. 1,028 IRBI observations).

## Benchmarks (M1 Pro)
Reference (real exposure, 1,946 flood events per term): 3.10 ms per tick median, 3.43 ms max. Worst case: 3.37 ms median. Case evaluation < 0.1 ms. Load 4.5 ms. The first save in a fresh directory took about 21 ms; subsequent saves take about 4.6 ms (first-write cost).

## Gaps
- **G-13**: absolute flood frequency, severity and seasonality are uncalibrated design coefficients (target sources: BNPB DIBI event history, BMKG climate normals).
- **G-14**: the IRBI flood table (2024 and 2023) omits 117 kab/kota, including all of Bali and Kepulauan Riau. The reason isn't stated in the parsed text. These regions keep exposure 0 and are labeled; this almost certainly understates their hazard.
- **G-01**: BPS key still missing (population, IPM, poverty, unemployment, PDRB).

## Next action
1. BPS key (human), then population, IPM, poverty, unemployment, PDRB.
2. Resolve G-14 (InaRISK service when it is back up; or BNPB clarification).
3. Policy system.
