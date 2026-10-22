# Execution report: data calibration sprint, milestone 1

Date: 2026-10-05 · Agent: Claude Code · Direction approved by Galih (D-019).

## Completed
- **Variable inventory and source mapping** (`research/data/VARIABLE_INVENTORY.md`): 20 observation variables with definition, unit, resolution, expected period, best source and status; calibration rule and justification for every simulation variable; conflict and resolution policies.
- **Four-layer separation implemented** (D-020): observation schema, observation writer/reader with validation, calibration builder, and game export of REAL reference facts kept separate from simulated variables.
- **BPS WebAPI connector**: key from `.env` only; raw capture before parsing; strict parser that rejects any response it cannot decompose unambiguously; `-`/blank values become `NOT_PUBLISHED`, never 0; variable discovery by keyword (no guessed IDs).
- **First real observation set**: `area_km2` for 514/514 kab/kota (BIG, edition 2023-09). The UI shows it as "NYATA · BIG 2023-09".
- **Calibration builder**: rules (identity, ratio_pct, copy); period choice; province-proxy fallback; per-region status; coverage report.
- **CASE-0001 hardened as the gold standard**: three simulated follow-up branches (A always after 2 quarters; B only if Bogor/Lebak recovery lags; C only if DKI sentiment falls); schema rules that keep follow-ups from claiming real facts; modal labels.
- **Session refactor** so full playthroughs are testable headless.

## Tested
| Suite | Result |
|---|---|
| Godot headless (simulation, save, content, case engine, CASE-0001 gold standard) | **26/26** |
| Python pipeline tests (BPS parser, observations, calibration) | **14/14** |
| Schema validation (registry, baseline, cases, research, 514 observations) | OK |

The gold-standard suite covers: attribution, fictional briefing, three decisions, immediate vs delayed effects (month-exact), regional divergence, emergent national price spillover, fiscal impact, sentiment recovery, state-dependent branching, a decision gate, and a golden master.

## Metrics
- Tick: 2.46 ms median for 514 regions (M1 Pro); 60-tick term 148 ms; 10× stress 24.9 ms per tick.
- Save: 89 KB, 1.5 ms serialize.
- Baseline status: 14/14 simulation variables still `UNCALIBRATED`; 1 REAL reference fact per region (area).

## Findings
1. **Design gap (G-11)**: infrastructure built in CASE-0001 choice C never pays off in sentiment, because the model has no recurring hazard whose damage infrastructure mitigates. Planned fix: flood exposure/mitigation from BNPB risk data plus recurring rainy-season flood events. No arbitrary bonus was added.
2. Trust half-life is about 34 months (trust smoothing 0.04 × sentiment trust weight 0.5). A trust hit from one decision lingers for most of a term. This is intended as "historical memory", but it should be reviewed in playtests.

## Blockers
1. **BPS WebAPI key** (human). Without it there are no population, IPM, poverty, PDRB or rice data.
2. **Government hosts unreachable** from this machine since ~11:45 UTC (G-10); probes are logged. If this persists, a team member in Indonesia could run `scripts/connectors/bps_webapi.py` locally once the key exists.

## Next recommended action
1. As soon as access works: discover and fetch BPS `pop_total`, `ipm`, `poverty_p0`, `unemployment_tpt`, `pdrb_adhb` for all 38 province domains → observations → calibrate `population`, `welfare_base`; benchmark again.
2. Meanwhile: hazard exposure/mitigation mechanic (G-11), then the **budget system** (sector allocation driving `services`/`infrastructure`/`fiscal_space`), designed against APBN categories so real APBN 2026 totals can drop in.
