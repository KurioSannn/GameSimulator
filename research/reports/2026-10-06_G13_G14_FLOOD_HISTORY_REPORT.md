# Execution report: G-13 / G-14 resolved with BNPB disaster-event history

Date: 2026-10-06 · Agent: Claude Code · Plan: `research/data/FLOOD_CALIBRATION_PLAN_G13_G14.md` (written before implementation)

## 1. Sources
| Source | Result |
|---|---|
| BNPB CKAN (data.bnpb.go.id), package `kompilasi-data-jumlah-dan-dampak-kejadian-bencana-2024` (BNPB Pusdatinkom, ODbL) | **Ingested via the documented DataStore API**: 10 kab/kota tables × BANJIR column (events, deaths, missing, injured, affected, displaced, houses, schools, health facilities, bridges damaged), 450 kab/kota |
| Same portal, direct XLSX downloads | Cloudflare challenge. The HTML challenge pages were deleted, never archived; no bypass |
| BNPB yearly packages 2002–2023 | Hosted in public Google Drive folders. **Drive robots.txt disallows the download endpoints** (`/uc`, `drive.usercontent.google.com`), so no automated download (**human action**, G-15) |
| 2000, 2001 | In the DataStore (32/38 and 1/38 provinces), but not used for frequency: they predate many regency splits and BNPB (est. 2008); recording practices differ |
| 2025 compilation | province level only |
| BNPB InaRISK ArcGIS | HTTP 521 (down) |

Validation: kab/kota flood events sum to **1,428** vs BNPB's own national row **1,420** (+0.6%, logged as conflict G-16; source values kept as published). All 450 codes matched the registry; one cosmetic name difference.

## 2. Schema: official vs derived (request §1, §5)
| Name | Layer | Meaning |
|---|---|---|
| `official_irbi_flood_score` (obs; unit "skor IRBI"; source SRC-BNPB-IRBI-2024; period 2024) | REAL | official BNPB **risk** index, as published |
| `official_irbi_total_score` (obs) | REAL | official multi-hazard risk index |
| `bnpb_flood_events`, `bnpb_flood_affected`, … (obs; per year) | REAL | recorded events and impacts |
| `flood_risk_profile` (sim; unit "indeks 0–100 (turunan)") | DERIVED | 100 × official score / 36; **not an official percentage**; severity modifier only |
| `flood_frequency` (sim; events/yr) | DERIVED | Gamma–Poisson rate from BNPB history |
| `flood_events_last`, `flood_damage_last`, `damage` | SIMULATED | per tick |
| `flood_protection` | SIMULATED | built during the term |

`flood_exposure` was removed. The IRBI index is never called hazard or exposure.

## 3. Exact relationships (v0.5)
Per region per month:
- **events** k ~ Poisson(λ_i × s_m). λ_i = `flood_frequency`; s_m = month's share of the seasonal profile (profile still UNCALIBRATED).
- **impact** = Σ_k min(40, Exp(μ)) × (0.5 + profile_i/100) × (1 − 0.75 × protection_i/100) × clamp(1.25 − 0.5 × infrastructure_i/100, 0.75, 1.25)
- **μ = 0.961** damage points per event, derived by `build_hazard_calibration.py` to preserve the validated national expected damage (§5).
- Budget: disaster-sector protection is weighted by λ_i / (λ_i + national mean λ), so money goes where floods happen.
- Recovery, welfare and sentiment chains are unchanged.

**Frequency rule** (Gamma–Poisson empirical Bayes):
- λ_i = (β·m_p + y_i) / (β + n_i), with y_i = recorded events and n_i = observed years.
- Fitted from the data: α = 1.174, β = 0.370 years (weak prior; observed record dominates), national mean 3.17 events per kab/kota per year.
- The province prior m_p is itself shrunk toward the national mean, so it is never 0.
- Coverage: 450 REAL (data-informed), 51 PROVINCE_PROXY, 13 UNCALIBRATED (national prior). **All 514 have λ > 0.**

## 4. G-14 resolution
Of the 117 regions without an IRBI flood score:
- 100 are in BNPB's 2024 table (77 recorded at least one flood);
- the other 17 get labeled proxies.

Example: Kab. Bangli has no IRBI flood score but recorded floods, so it gets a REAL frequency and a neutral, labeled profile. Kota Denpasar has neither, so it gets a PROVINCE_PROXY rate. No region is suppressed to zero, and no risk score is fabricated.

## 5. Severity calibration (request §6): investigated, partially possible
- BNPB 2024 provides **annual totals per kab/kota**, not per-event records: median ≈ 990 people affected per flood event (p90 ≈ 11,200).
- Converting that to the damage index needs regional population, which is blocked on the BPS key (G-01).
- So severity stays a **labeled model**: Exp(μ) × modifiers, with μ normalized to the previously validated national expected damage.
- Documented activation rule once population exists: `points_per_event_i = 100 × (affected_i / events_i) / population_i`.
- No historical severity values were invented.

## 6. G-11 (mitigation payoff), reworked
Mitigation and resilience multiply the impact of **future** events only. Proven by tests on identical events: protection 60 cuts impact by exactly 45%; infrastructure 80 vs 20 cuts impact by >20%.

CASE-0001 outcome matrix (seed 11; identical events in every row):

| CASE-0001 | recurring (R) | budget | flood events (7 regions) | cum. flood damage | end protection | end welfare | end sentiment (focus) | min sentiment (Jkt Pusat) | fiscal space | national sentiment | cases seen |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| a | a | baseline | 138 | 220.6 | 0.0 | 53.5 | 47.9 | 47.0 | 45.0 | 49.92 | 3 |
| a | b | baseline | 138 | 214.9 | 15.0 | 53.2 | 46.9 | 47.0 | 43.0 | 49.90 | 3 |
| a | c | baseline | 138 | 218.1 | 6.0 | 53.1 | 47.0 | 47.0 | 46.5 | 49.90 | 3 |
| b | a | baseline | 138 | 220.6 | 0.0 | 53.7 | 47.2 | 41.5 | 40.0 | 50.56 | 3 |
| b | b | baseline | 138 | 214.9 | 15.0 | 53.4 | 46.2 | 41.5 | 38.0 | 50.54 | 3 |
| b | c | baseline | 138 | 218.1 | 6.0 | 53.3 | 46.3 | 41.5 | 41.5 | 50.54 | 3 |
| c | a | baseline | 138 | 182.9 | 27.1 | 52.8 | 45.1 | 37.7 | 41.0 | 50.52 | 2 |
| c | b | baseline | 138 | 182.9 | 27.1 | 52.8 | 45.1 | 37.7 | 41.0 | 50.52 | 2 |
| c | c | baseline | 138 | 182.9 | 27.1 | 52.8 | 45.1 | 37.7 | 41.0 | 50.52 | 2 |
| c | b | +5% kebencanaan | 138 | 167.2 | 47.1 | 52.4 | 46.2 | 39.1 | 41.0 | 50.38 | 2 |
| a | a | +5% kebencanaan | 138 | 204.8 | 19.9 | 52.6 | 47.6 | 47.8 | 48.0 | 49.75 | 2 |

National, untouched term:

| tick | month | regions flooded | mean damage | max damage | national welfare | national sentiment | regions <40 sentiment |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 6 | 6 | 29 | 1.45 | 18.4 | 54.51 | 54.17 | 0 |
| 12 | 12 | 189 | 1.94 | 13.7 | 53.97 | 53.50 | 1 |
| 18 | 6 | 32 | 2.44 | 16.8 | 53.41 | 52.39 | 2 |
| 24 | 12 | 192 | 2.65 | 18.2 | 53.34 | 51.99 | 2 |
| 30 | 6 | 29 | 2.95 | 15.6 | 53.00 | 51.12 | 7 |
| 36 | 12 | 199 | 2.85 | 15.7 | 53.10 | 51.00 | 4 |
| 42 | 6 | 28 | 3.09 | 18.2 | 52.87 | 50.36 | 7 |
| 48 | 12 | 178 | 2.95 | 17.0 | 53.02 | 50.36 | 10 |
| 54 | 6 | 28 | 3.14 | 21.4 | 52.83 | 49.84 | 15 |
| 60 | 12 | 186 | 2.92 | 20.0 | 53.01 | 49.92 | 13 |
total regional flood events over term: 5798 (2.92 per exposed region per year)

## 7. Bugs found → fixed → regression tests
| Bug | Fix | Test |
|---|---|---|
| 5 regions got λ = 0: a province prior of 0 when every observed region in the province recorded zero floods (artificial suppression) | hierarchical province prior shrunk to the national mean | `test_no_region_has_zero_flood_rate`, `test_province_all_zero_still_positive` |
| CASE-0001-R relief targeted every flooded region nationwide ("where:" over all regions), so a Jakarta case funded relief in ~190 regions | `where:…&in:<case regions>` scope | `test_recurring_relief_stays_in_case_area` |
| Tests assumed distant regions never flood | hazard-free worlds where the test isolates another mechanism | — |

## 8. Tests
- Godot **49/49**. New: 8 in `test_flood_calibration.gd` (official vs derived, IRBI+history, history without IRBI, neither, no zero rates, prior strength, mitigation on identical events, resilience), plus 2 in CASE-0001 (recovery with and without background floods; relief scope).
- Pipeline 18/18 (4 new Gamma–Poisson tests). Schema validation OK.
- Golden master regenerated (reason: BNPB-history frequency model, D-032).

## 9. Benchmarks (3 runs, M1 Pro)
| Scenario | Events/term | Tick median | p95 | Save | Load |
|---|---:|---:|---:|---:|---:|
| reference (real data) | 5,836 | 3.44–3.50 ms | 3.8–3.9 ms | 21 ms first save / ~5 ms after | 5.0 ms |
| worst case (λ = 20/yr everywhere) | 19,783 | 4.42–4.45 ms | 6.4–6.7 ms | 5–6 ms | 4.8–5.0 ms |
| stress 10× (5,140 regions) | 195,628 | 43.4–43.5 ms | 63.4 ms | 29–30 ms | 42–43 ms |

Case evaluation < 0.1 ms. All 514 regions are simulated every monthly tick.

## 10. Remaining gaps
- **G-15 (human)**: BNPB 2002–2023 kab/kota files are in Drive folders (robots disallow automated download). Download them in a browser into `data/raw/bnpb/drive_manual/<year>/`; a parser will be added once the real layout is visible. This makes the frequency genuinely multi-year.
- **G-01 (human)**: BPS key → population → empirical severity anchor.
- **G-13 (remaining)**: seasonal profile is still generic (BMKG normals); severity μ is a normalization, not yet empirical.
- **G-16**: BNPB kab/kota sum vs national total differ by 8 events (0.6%).
- Balancing: the flood-control path still ends with lower Jakarta sentiment (trust cost); the recurring case no longer appears on that path because protection prevents damaging months.
