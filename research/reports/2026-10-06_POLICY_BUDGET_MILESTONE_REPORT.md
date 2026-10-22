# Execution report: policy + budget system milestone

Date: 2026-10-06 · Agent: Claude Code. No socioeconomic or fiscal values were fabricated; all magnitudes are labeled design values.

## 1. Policy architecture
- **Data**: `game/data/policies/*.json` (schema `data/schemas/policy.schema.json`), categories in `game/data/policy_categories.json` (14: pangan, ekonomi, energi, pendidikan, kesehatan, lingkungan, infrastruktur, industri, digitalisasi, sosial, kebencanaan, pemerintahan, kebudayaan, pembangunan_daerah).
- **Engine**: `src/sim/policy_engine.gd`, one generic class with no per-policy scripts.
  - `can_enact` checks: known policy, not already running, cooldown, mutual exclusion, prerequisites (shared condition DSL), valid non-empty target after the regional eligibility filter, upfront affordability.
  - `enact` applies the upfront cost, starts the running commitment, draws one deterministic uncertainty multiplier (counter RNG), resolves the target to an explicit region list, and schedules phased effects through `EffectQueue`.
  - Lifecycle: IMPLEMENTING → ACTIVE → ENDED (cooldown).
- **Targeting**: national, island group, province, kab/kota, selected regions. `target_filter` (e.g. `flood_frequency>=3`) sets regional eligibility.
- **Regional response**: an effect's `scale_by` makes a national policy differ by region.
  - capacity mode: m = clamp(var/ref) (stronger services implement more);
  - gap mode: m = clamp((100 − var)/(100 − ref)) (more effect where the variable is low).
- **Case linkage**: shared `Conditions` adds `policy_active` and `policy_enacted`; policies can also set memory flags. Cases can therefore depend on policy decisions (tested).
- **Local-wisdom hook**: `cultural_basis` must reference a researched `research/culture/records/<id>.json` with a completed mechanic mapping and sensitivity review. The validator enforces this. All prototypes have `null` (no cultural mechanic invented).
- **Persistence**: `SimWorld.policy_state` saved (schema v3, v2 migration).

## 2. Policy data schema (fields)
`policy_id, name, category, description, fact_class (FICTIONAL), provenance {basis, references}, target_scope[], target_filter, cost {upfront_fiscal, monthly_commitment, commitment_months}, implementation_months, duration_months, cooldown_months, prerequisites (condition DSL), mutually_exclusive[], uncertainty {magnitude}, effects[] {phase: immediate|implementation|active, scope: target|national, var, op, value, delay, duration, scale_by, kind: expected|delayed, dimension: regional|national|stakeholder|sentiment|environmental|fiscal, label}, stakeholder_notes[], follow_up_case_triggers[], memory{}, cultural_basis, game_design_notes`.

The requested fields expected/delayed/regional/national/stakeholder/sentiment/environmental effects are expressed as `effects[].kind` and `effects[].dimension`: one source of truth, grouped in the UI.

## 3. Budget architecture (three layers, D-039)
| Layer | Where | Status |
|---|---|---|
| REAL fiscal data | observations `apbn_*`/`apbd_*` | none ingested (DJPK unreachable; APBN not yet sourced) |
| GAME fiscal baseline | `game/data/budget.json` from `build_budget.py`: `pool_rp` (null), sector base shares (neutral, UNCALIBRATED) | unchanged |
| SIMULATED budget state | `national.budget_level`, `budget_shares`, `fiscal_space`; `policy_state` commitments; `Simulation.fiscal_report()` ledger | new ledger |

`data/calibration/fiscal_structure.json` maps every requested concept to its layer, current game role and candidate official classification (TO_VERIFY): revenue, expenditure, balance, financing, transfers to regions, functional spending, capital expenditure, emergency/disaster, development, policy spending, remaining capacity. Transfers to regions and capital expenditure are explicitly *not simulated yet*. Unit: **FU** (100 FU = one year of the baseline program envelope). Real rupiah are a display conversion through `pool_rp`, so real 2026 figures plug in without equation changes.

## 4. Causal effect model (exact)
Monthly:
- commitment C = Σ running policy commitments
- spending = max(level, C); fiscal_space += 5 × (1 − spending)
- sector intensity_k = max(0, level − C) × share_k / base_share_k. **Running policies crowd out sector programmes.** That is the opportunity cost.

Policies act only on **upstream state**; downstream variables follow the existing model:

| Policy (prototype) | Acts on | Downstream chain |
|---|---|---|
| Rehabilitasi Jaringan Irigasi | food_capacity ×1.0025/month × services capacity (after 6-month implementation) | food supply → price → welfare → sentiment (tested: more supply, lower prices) |
| Normalisasi Sungai dan Drainase | flood_protection +1.5/month (after 9 months), only where flood_frequency ≥ 3; trust −0.2/month and environment −0.1/month during construction | lower impact of future floods (not frequency) → less damage → welfare/sentiment |
| Bantuan Langsung Tunai Sementara | welfare +0.8/month for 6 months, larger where welfare is low (gap) | transient (welfare converges back to welfare_base); 8% commitment crowds out capacity sectors |
| Program Peningkatan Jalan Daerah | infrastructure +0.4/month × infrastructure gap (after 12 months); environment −0.05/month during construction | logistics → food realization/trade → price; flood resilience; recovery speed |
| Penguatan Kapasitas Layanan Daerah | services +0.25/month × services gap; uncertainty ±35% | recovery speed, welfare |
| Program Layanan Terpusat | services +0.4/month uniform; prerequisite fiscal_space ≥ 15; more expensive | same; mutually exclusive with the decentralized variant |

Each prototype has a benefit, cost, opportunity cost, delay, regional difference and uncertainty. None is dominant: e.g. the cash transfer is fastest but leaves no capacity, and roads help most where infrastructure is worst but take 12 months.

## 5. Counts
- Prototype policies: **6** (5 categories used; framework covers 14).
- Tests: Godot **63** (+14 policy), pipeline **22**, schema/content validation incl. policy checks.

## 6. Bugs found → fixed
| Bug | Fix | Regression |
|---|---|---|
| **Test runner hung forever** when a suite failed to parse (`.new()` on a broken script aborted `_initialize` before `quit()`); a 10-minute hang during this milestone | runner checks `can_instantiate()` and records a failure | verified with a deliberately broken suite (reported in 8 s) |
| Effects re-parsed 514-id scope strings every tick | runtime scope cache on SimWorld (not saved) | full suite + benchmark |

## 7. Benchmarks (3 runs, M1 Pro)
| Scenario | Tick median | p95 | max | Load |
|---|---:|---:|---:|---:|
| reference (real data) | 3.43–3.46 ms | 3.8 | 3.9 | ~5 ms |
| worst case (floods 20/yr everywhere) | 4.39–4.44 ms | 6.4 | 6.6 | ~4.7 ms |
| **policies_active** (worst case + 5 national policies) | **5.81–5.88 ms** | 8.1 | 8.7 | ~4.9 ms |
| stress 10× | 43.5 ms | 63.3 | 64 | 41 ms |

Policy effects run per region inside the normal monthly simulation (no shortcut). Five national policies cost about 1.4 ms per tick. Save with policies: 112 KB.

## 8. Remaining data dependencies
- G-01 BPS key → population, IPM, poverty, unemployment, PDRB (welfare_base, population weights, severity anchor).
- APBN/APBD real values and verified classification mapping → `pool_rp`, base shares, fiscal_space scale.
- G-15 BNPB 2002–2023 manual downloads → multi-year flood frequency.
- G-12 sources for services and environment baselines.
- Policy magnitudes are uncalibrated design values until the variables they act on are calibrated.

## 9. Architecture changes
`Conditions` (shared DSL), `PolicyEngine`, `EffectQueue.scale_by` + scope cache, budget commitment integration, `Simulation.fiscal_report`, save schema v3, `Session.enact_policy`/`Game.enact_policy`, `PolicyPanel` UI, budget ledger line, `fiscal_structure.json`, runner robustness.
