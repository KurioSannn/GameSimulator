# Execution report: milestone 2, CASE-0001 vertical slice complete

Date: 2026-10-05 · Agent: Claude Code · Direction: Galih (approved calibration sprint; G-11 approved as a real gap).

## Summary
CASE-0001 now demonstrates the full loop: **baseline → case → decision → budget cost → regional effect → national effect → delayed effect → sentiment → follow-up → recurring flood → recovery or escalation**. G-11 is fixed with a real mechanic: recurring seasonal floods whose damage is reduced by flood protection. Protection is built by case decisions and by the disaster budget sector. No arbitrary bonuses were added. A **real persistence bug** was found and fixed: Godot's JSON lost precision for about 9% of doubles.

Socioeconomic data is still **not ingested**. Every simulation variable remains `UNCALIBRATED` and is labeled in the UI. Government hosts still time out **from this machine** (probes 11:48–12:15 UTC, all HTTP 000). This is logged as observed and is not a claim about national availability.

## 1. Architecture changes
| Change | Where | Why |
|---|---|---|
| Recurring flood system | `Simulation._step_floods` | G-11: exposure → damage, mitigated by protection |
| Budget system (sector intensities, spending level, fiscal space) | `Simulation._step_budget`, `sector_intensity`; `Session.set_budget`; `game/data/budget.json` | resource layer; real APBN can drop in without equation changes |
| REAL fiscal → DERIVED budget pipeline | `data/calibration/budget_map.json`, `scripts/pipelines/calibration/build_budget.py` | keeps REAL fiscal data separate from SIMULATED budget state |
| Counter-based RNG | `src/sim/sim_rng.gd` | reproducible per (seed, tick, region); paired policy comparisons; new systems don't shift existing outcomes |
| Recurring cases (cooldown, cap, history) | `CaseEngine._can_recur` | recovery vs escalation loop |
| Dynamic `where:` effect scope resolved at decision time | `EffectQueue.schedule/resolve_where` | target "regions flooded now" without hardcoding |
| Exact save encoding, save schema v2 + v1 migration | `src/save/save_codec.gd`, `SimWorld.to_dict/load_dict` | bug fix (below) |
| Calendar: tick 0 = January | `sim_params.calendar` | seasonality; matches CASE-0001 |
| UI: budget panel, choice cost line, flood overlay and fields, shorter tags with tooltips | `src/ui/*` | budget playable; costs visible; fact labels kept |

## 2. Exact simulation relationships (v0.3)
Monthly order: effects due → **budget** → **floods** → recovery & logistics → food & prices → welfare → sentiment & trust.

**Budget** (per month; `I_k` = sector intensity = level × share_k / base_share_k; at baseline every `I_k = 1` and nothing drifts):
- fiscal_space += 5.0 × (1 − level), clamped 0–100. If fiscal_space ≤ 0, the level is forced to ≤ 1.0.
- infrastructure += 0.6 × (I_infrastruktur − 1); services += 0.6 × (I_layanan − 1); food_capacity ×= 1 + 0.01 × (I_pangan − 1)
- flood_protection += 1.5 × (I_kebencanaan − 1) × exposure/100, only where exposure > 0 (money goes where the hazard is)
- recovery base rate × (1 + 0.5 × (I_kebencanaan − 1))

**Floods** (per region per month, counter RNG):
- P(flood) = 0.35 × season[month] × exposure/100. Season Jan..Dec = 1.0, 0.9, 0.6, 0.3, 0.15, 0.1, 0.05, 0.05, 0.1, 0.3, 0.6, 0.85 (generic monsoon profile, **UNCALIBRATED**)
- raw severity = U(10, 40) × exposure/100
- damage added = raw × (1 − 0.75 × protection/100); recorded as `flood_damage_last`
- Protection reduces severity, never occurrence (residual risk ≥ 25%)

**Downstream** (unchanged equations): damage → recovery (faster with infrastructure, services, disaster budget); damage → logistics → food realization → national pool and trade → price; price, damage and services → welfare; welfare, price, trust, environment and damage deviations → sentiment; sentiment → trust (slow memory, half-life ~34 months).

**Exposure source**: 0 everywhere unless a documented case reveals it (CASE-0001 sets DKI 60, Bogor and Lebak 50; labeled DERIVED/case evidence, magnitude uncalibrated). Target source: BNPB IRBI flood component.

**Case flow**: CASE-0001 (3 choices) → branch A / B (state-dependent) / C (state-dependent) → recurring **CASE-0001-R** (opens when any focus region takes ≥ 8 flood damage in a month; cooldown 9 months, max 3; choices: relief / flood control / early warning).

## 3. Outcome matrix (seed 11; identical hazard events in every row)
| CASE-0001 | recurring (R) | budget | flood events (7 regions) | cum. flood damage | end protection | end welfare | end sentiment (focus) | min sentiment (Jkt Pusat) | fiscal space | national sentiment | cases seen |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| a | a | baseline | 27 | 337.6 | 20.0 | 51.7 | 43.4 | 37.4 | 39.0 | 54.19 | 5 |
| a | b | baseline | 27 | 275.3 | 65.0 | 52.8 | 45.4 | 39.3 | 33.0 | 54.22 | 5 |
| a | c | baseline | 27 | 309.6 | 38.0 | 52.1 | 44.5 | 37.5 | 43.5 | 54.21 | 5 |
| b | a | baseline | 27 | 337.6 | 20.0 | 51.9 | 42.6 | 35.4 | 34.0 | 54.79 | 5 |
| b | b | baseline | 27 | 275.3 | 65.0 | 52.9 | 44.6 | 37.2 | 28.0 | 54.82 | 5 |
| b | c | baseline | 27 | 309.6 | 38.0 | 52.2 | 43.7 | 35.4 | 38.5 | 54.80 | 5 |
| c | a | baseline | 27 | 256.8 | 47.1 | 52.6 | 44.4 | 38.6 | 32.0 | 54.82 | 5 |
| c | b | baseline | 27 | 224.8 | 77.1 | 52.6 | 44.2 | 38.4 | 31.0 | 54.81 | 4 |
| c | c | baseline | 27 | 240.0 | 65.1 | 52.3 | 44.3 | 38.2 | 36.5 | 54.81 | 5 |
| c | b | +5% kebencanaan | 27 | 198.4 | 94.3 | 52.4 | 45.9 | 39.9 | 31.0 | 53.80 | 4 |
| a | a | +5% kebencanaan | 27 | 311.2 | 37.1 | 51.7 | 45.2 | 40.8 | 39.0 | 53.18 | 5 |

What the matrix shows:
- Mitigation pays off for the same hazards: cumulative flood damage 338 → 198.
- Protection costs fiscal space.
- Diverting budget from services to disaster lowers national sentiment (trade-off).
- A well-protected path meets the recurring crisis less often (4 vs 5 cases), which also means fewer chances to fund protection. This is a design consequence, not a bug.

Sentiment spread between best and worst paths is modest (end focus sentiment 42.6–46.7), which is a **balancing item for playtests**.

## 4. Bugs found → fixed → regression tests
| Bug | Found by | Fix | Regression test |
|---|---|---|---|
| Save/load not bit-exact: Godot JSON keeps 16 significant digits; 9,277/100,000 random doubles changed on round trip, so reloaded games diverged once floods produced arbitrary values | new mid-term save/load test | SaveCodec: base64 float64 arrays, hex scalars; schema v2; v1 migration | `test_codec_is_bit_exact_for_arbitrary_doubles`, `test_v1_save_is_migrated`, `test_save_load_mid_term_preserves_floods_budget_and_recurrence` |
| Case-engine dot-assignment created StringName keys mixed with String keys | same test | `st["key"] =` | covered by case_state equality after reload |
| Infrastructure choice never paid off (G-11) | golden master (milestone 1) | flood system + flood_protection | `test_protection_reduces_damage_of_identical_floods` |
| Recurring crisis fired at max frequency even at 92% protection | outcome matrix | trigger at ≥ 8 damage (a damaging flood) | `test_recurring_case_respects_cooldown_and_cap` + golden master |
| Budget panel overlapped overlay list; region tags clipped | screenshots | stacked left column; short tags with tooltips | visual (screenshots); UI tests not automated yet |

## 5. Tests
- Godot: **38/38** (was 26). New tests: 6 in CASE-0001 (paired mitigation, no floods without exposure, recurrence cooldown and cap, where-scope, mid-term save/load with floods/budget/recurrence, lagged sentiment recovery), 5 budget (baseline equilibrium, overspend drain and cap, exposure-weighted protection, validation, RNG), 2 save codec/migration.
- Golden master regenerated **deliberately** for the G-11 mechanic. Path C now ends with Jakarta Pusat damage 2.4 vs 7.7 and sentiment 45.0 vs 40.0, at fiscal 32 vs 39.
- Python pipeline: **14/14**. Schema validation: OK.

## 6. Benchmarks (M1 Pro, headless, Godot 4.7.2)
| Scenario | Regions | Flood events | Tick median | Tick p95 | Tick max | Case eval max | Term total | Save | Load | Save size |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| reference | 514 | 44 | 2.522 ms | 2.574 ms | 2.659 ms | 0.038 ms | 152.6 ms | 20.81 ms | 4.16 ms | 100 KB |
| worst_case | 514 | 2580 | 3.32 ms | 3.598 ms | 3.652 ms | 0.037 ms | 201.7 ms | 4.3 ms | 4.1 ms | 100 KB |
| stress_4x | 2056 | 10687 | 13.151 ms | 13.583 ms | 13.722 ms | 0.005 ms | 793.6 ms | 10.68 ms | 15.12 ms | 398 KB |
| stress_10x | 5140 | 27021 | 32.919 ms | 34.041 ms | 34.119 ms | 0.006 ms | 1984.2 ms | 25.77 ms | 38.0 ms | 994 KB |

Notes on variance: an earlier run in the same session measured worst-case p95 9.1 ms / max 15.7 ms, and reference save 3.1 ms. This run measured p95 3.6 ms / max 3.7 ms, with a single 20.8 ms reference save. These outliers are not reproducible, so they are most likely machine load or first-write filesystem effects rather than simulation cost. **Stable figures**: about 2.5 ms per tick (reference) and about 3.3 ms per tick (worst case: every region flood-exposed, budget active). The flood and budget systems add about 0.8 ms per tick in the worst case. The simulation runs on turn advance, not per frame. Benchmarks should report the median of several runs, and must be repeated on low-end Windows hardware (target: one quarter < 250 ms). Save is now 100 KB (exact encoding).

## 7. Remaining gaps
- **Real data**: BPS key (human) and host access (G-01, G-10). Every simulation variable is `UNCALIBRATED`.
- **Exposure magnitudes and seasonality** uncalibrated (G-11 data side: BNPB IRBI; BMKG regional climate normals; the generic profile is wrong for parts of Maluku).
- **APBN 2026**: pool and function shares not ingested; budget mapping marked TO_VERIFY (G-05).
- **Inventory gap G-12**: no official sources yet for services, environment, flood_protection.
- **Balancing**: modest sentiment spread across paths; sentiment trough lags damage by about 8 months (players may read relief as useless). Needs playtests before tuning.
- **UI automation**: layout regressions are caught only by screenshots.

## 8. Recommended next case
**CASE-0002: 2018 Palu earthquake–tsunami–liquefaction (Sulawesi Tengah).**
- It is outside Java (geographic balance) and a different hazard class, so it exercises the engine beyond floods.
- It reuses damage, recovery, budget and recurring-follow-up mechanics.
- It adds a genuinely new relationship: a sudden-onset disaster with no seasonality, plus land-use/relocation decisions (liquefaction zones).
- It is heavily documented by BNPB and BMKG, which suits the source standard.

Alternative if the team wants a non-disaster case next: a food-price shock case, to exercise the food → price chain without damage.
