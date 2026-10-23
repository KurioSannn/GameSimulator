# 31 REGIONAL SIMULATION INTEGRATION

How a decision becomes regional consequences that the player can see and understand. This is the runtime contract. Results are in `research/reports/2026-10-22_REGIONAL_SIMULATION_REPORT.md`.

## 1. Loop

`Session.decide` → `CaseEngine.decide` (choice effects) [+ `PolicyEngine.enact`] → `SimLedger.scheduled_entry` (event log) → `Session.advance_quarter` → `SimLedger.begin` → 3 × `Simulation.step_month` over all 514 regions (effects due, then budget, floods, recovery/logistics, food/prices, welfare, sentiment/trust) → `SimLedger.quarter_entry` (event log) → UI refresh: map, region panel, top bar.

- **Time:** time never advances while a case is pending (`advance_quarter` returns nothing).
- **Quarter length:** a quarter is 3 monthly ticks. This is the existing semantics (`SimWorld.TICKS_PER_QUARTER`, 60-tick term), kept unchanged (D-064).
- **When effects apply:** a choice effect with `delay: 0` applies in the first simulated month after the decision ("segera"). A delay of d applies d months later ("tertunda"). A duration > 1 re-applies monthly ("berlanjut").

## 2. Data layers (unchanged separation)

| Layer | Where | Label in UI |
|---|---|---|
| Observed / sourced facts | `regions.json` facts, `baseline.json` REAL / PROVINCE_PROXY | NYATA, AWAL: DATA ‹year›, AWAL: PROKSI PROVINSI |
| Derived starting values | `baseline.json` (e.g. flood_frequency) | AWAL: DATA ‹year› with sources in the tooltip |
| Uncalibrated neutral start | `baseline.json` status UNCALIBRATED | BLM KALIBRASI; hatched on the map |
| Simulated state | `SimWorld.vars` | SIMULASI |
| Attribution / history | `SimWorld.ledger`, `SimWorld.event_log` | "Perubahan kuartal terakhir", "Catatan" |

No statistic is invented. Uncalibrated variables start from the documented neutral defaults.

## 3. Attribution: `SimLedger` (`game/src/sim/sim_ledger.gd`)

- **Coverage:** for the quarter in progress or the last one, the ledger holds, per tracked variable, the start values of all 514 regions plus summed per-region deltas for each cause.
- **System causes:** `sys:budget|floods|recovery|food_prices|welfare|sentiment`.
- **Effect causes:** `eff:<source>#now|delayed|ongoing`, where the source is `case:<id>/choice:<c>`, `case:<id>/trigger` or `policy:<id>`.
- **Exact by construction:** every system step and every applied effect records `after − before`. The steps run sequentially, so the causes of a variable sum to `now − start` in every region (tested: max error < 1e-9 over all regions and variables).
- **Observational only:** the ledger uses no RNG and writes no simulation state. Outcomes are bit-identical with and without it (tested, and all golden masters unchanged).
- **Cost:** ≈ 3.3 ms per quarter (13.8 vs 10.5 ms, M1 Pro).

## 4. National aggregation (D-063)

`SimWorld.national_mean` uses population weights only if **every** region has population > 0. Otherwise it uses an equal-weighted mean over all 514 regions, never a mix.

- Population is currently UNCALIBRATED (0), so national indicators are equal-weighted.
- The top bar says so: "rata-rata setara 514 wilayah (data penduduk belum terkalibrasi)".
- The quarter log entry records `weighting`.
- ▲▼ in the top bar is the change of the same aggregate over the last quarter.

## 5. Presentation

- **Map:** the overlay colours simulated values.
  - "Perubahan kuartal (C)" colours each region by its change over the last quarter: blue = down, orange = up, grey = unchanged. The scale is ±P95 of |Δ|, at least 0.5. The palette deliberately carries no good/bad judgement.
  - Regions whose starting value is UNCALIBRATED are hatched (texel alpha flag, `map_fill.gdshader`), so they never look like measurements. The legend states this and the count.
  - Hover and selection stay outline-based (separate from fill colour).
  - All 514 regions are coloured on every refresh. Only the 535-texel lookup texture is rewritten.
- **Region panel:**
  - identity (name, kind, Kemendagri ID, BPS code, province);
  - sentiment drivers;
  - **Perubahan kuartal terakhir:** each variable start → now (Δ) with its top causes, effect causes highlighted;
  - **Efek terjadwal:** pending effects reaching this region, with delay and duration;
  - each current value with "awal" (start of term, rebuilt from content, not saved) and its baseline status tag.
- **Event log (L)** (`SimWorld.event_log`, capped at 40, newest first): decision entries list each scheduled effect (variable, amount, scope with region count, immediate or delayed, duration). Quarter entries give national Δ, regions changed ≥ 0.5 and the top cause per variable. Text comes from `ChangeText`, which only formats recorded numbers.
- **Toasts:** after a decision, the counts of immediate and delayed effects and the coverage; after a quarter, the regions changed.

## 6. Save (schema 4)

`to_dict` adds `ledger` and `event_log` (exact `SaveCodec` encoding). Migration v1 → v2 → v3 → v4: a v3 save loads with an empty ledger and log, and attribution resumes with the next quarter. Quicksave/quickload restores state, pending effects, ledger and log bit-exactly (tested, and checked with F5/F9 in the QA checklist).

- **Size:** the save grows from about 115 KB to about 270 KB because of the per-region cause arrays.

## 7. Tests

`game/tests/test_regional_sim.gd` (9 tests):
- no advance while a case is pending;
- exact attribution for all 514 regions;
- ledger is observational;
- choice a vs b differ and are attributed (now / delayed / ongoing);
- event log content and cap;
- explicit weighting, never mixed;
- save/load of ledger, log and future;
- v3 → v4 migration;
- cause wording.

## 8. Crisis cases in the loop (2026-10-22, D-066 to D-068)

**National drivers.**
- CASE-0003's shock is a national scalar (`price_pressure`) that raises every region's price target. `SimWorld.drivers` records which effect sources make up its current value (shares scale together as the model decays it).
- Each month the part of every region's price change caused by the pressure is computed exactly (same step without pressure), then split across those sources as `drv:price_pressure|<source>`.
- The panel therefore says, for Kota Denpasar, "+8,1 Tekanan harga nasional: Kejadian kasus «Minyak Goreng…»; −3,4 … Larang ekspor CPO". Causes still sum exactly to the change.
- Outcomes are unchanged: the CASE-0001, 0002 and 0003 golden masters are identical.

**National ledger.**
- `fiscal_space` and `price_pressure` changes per quarter are attributed to decisions, case events, the budget model and shock decay. They are shown in the quarter log entry.
- A policy's upfront cost is listed in its log entry.

**Case presentation.**
- The map focuses on the case's regions.
- Follow-ups show **PEMICU**: their actual trigger conditions with current values (✓/✗), from `Conditions` and the same scopes.
- Every choice shows a preview read from its own effects: target regions, national levers, any policy and where it applies, and how far ahead consequences reach.
- Case events are logged with their scheduled effects.

**Panel.** A "Faktor nasional" section shows the current price pressure, its sources, scheduled national changes, and the documented limitation: the cooking-oil weight and provincial palm-oil dependence are not modelled.

**Map.** New overlays: Kepercayaan, Lingkungan, Pencegahan Api.

**Saves.** Schema 5 adds `drivers`. A v4 save shows any existing pressure as "sumber tidak tercatat" (not guessed).

**Local wisdom scope (CULT-0001).** POL-KEBENCANAAN-API-ADAT is enacted only in Kab. Kapuas (62.03), the documented location. This applies to CASE-0004 choice c, CASE-0004-A choice b, and the whole CASE-0004-C follow-up. Peat restoration stays province-wide: Kalteng is a BRG priority province.
