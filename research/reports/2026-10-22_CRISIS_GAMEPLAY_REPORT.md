# Crisis gameplay and cross-case consequences: execution report (2026-10-22)

Contract additions: `docs/31_REGIONAL_SIMULATION.md` §8. Decisions: D-066 to D-068.

## Inspection findings (before changes)
- CASE-0002/3/4 already resolved through `Session.decide`. Their regional effects, delays, follow-ups and policy enactments were recorded by the ledger introduced in `db44cc4`.
- **Gaps found by playing full terms headlessly:**
  1. **CASE-0003's central mechanism was invisible regionally.** The commodity shock and the export ban act on the national `price_pressure`, so regional price changes were attributed only to "model". Fiscal costs were not explained per quarter.
  2. **Documented-scope violation.** The Dayak Ngaju adat policy was enacted on all 14 kab/kota of Kalimantan Tengah (CASE-0004 c, CASE-0004-A b, and the CASE-0004-C follow-up). CULT-0001 documents Kapuas only, and its review forbids province-wide generalization.
  3. **Follow-up triggers were not inspectable;** only authored text was shown.
  4. **Choices did not reveal where they act** before deciding.
  5. **No map modes** for trust, environment or fire prevention, the key CASE-0002 and CASE-0004 variables.
  6. **Region panel clipped** by long source tags in "Data acuan".

## Changes
- **National drivers:** source shares, an exact regional split, and a national quarter ledger (D-066). Save schema 5 with v4 migration.
- **Adat mechanic** scoped to Kab. Kapuas, with updated choice and follow-up texts (D-067). The CASE-0004 golden master was regenerated deliberately; only choice c changed. CASE-0001 to 0003 golden masters are unchanged.
- **Case modal:** PEMICU (live condition values) and a per-choice reach preview (D-068). The map focuses the case's regions when a case is presented. Case events are logged.
- **Panel:** "Faktor nasional" (pressure, sources, scheduled national changes, limitation note); fact rows wrap.
- **Overlays:** Kepercayaan, Lingkungan, Pencegahan Api (2-column selector).
- **Automation:** `--play-to=<case> [--choices=…]` for screenshots.

## Multi-turn examples (same seed and full content as the game; `crisis_gameplay/multi_turn_examples.txt`)
Values are simulated. Most starting values are uncalibrated neutral defaults.

### CASE-0002, Palu (decided in month 22; Palu+Sigi mean)
| Choice | Damage, Q+1 | Damage, Q+5 | Trust, Q+5 | Fiscal space |
|---|---|---|---|---|
| a, rebuild in place | 22.8 | 9.4 | 48.8 | 41 |
| b, relocation | 35.7 | 3.6 | 44.7 | 39 |
| c, self-build | 35.7 | 10.9 | 46.9 | 44 → 42 |

- **a:** fastest early recovery.
- **b:**
  - slowest early recovery, but its delayed 12-month effects then bring damage lowest and services +3;
  - trust stays lowest, falling to 41.9 at Q+4;
  - the inspectable follow-up "Pulang ke Zona Merah" fires because trust is 47.9 < 54.
- **c:** cheapest; it later triggers the self-built-housing quality follow-up.

### CASE-0003, cooking oil (decided in month 40; national pressure +8 % at the event)
| Measure, Q+1 | a, export ban | c, subsidy + cash |
|---|---|---|
| Riau mean welfare | 50.6 | 53.0 |
| Riau trust | 49.5 | 51.4 |
| Denpasar price | 103.3 | 105.2 |
| National price pressure | 2.5 % | 5.7 % |
| Fiscal space | 39 (one-off) | 35, then 26 by Q+3 after the cash extension |

- **a:** producers pay and consumers nationwide benefit.
- **c:** the reverse, at a fiscal cost.
- **Panel for Denpasar:** "+8,1 Kejadian kasus «Minyak Goreng…»; −3,4 Keputusan …: Larang ekspor CPO".

### CASE-0004, peat fires (decided in month 46)
| Measure | a, total ban | b, restoration | c, community governance |
|---|---|---|---|
| Fire prevention | +20 in Kalteng and its neighbours immediately | 0 for 6 months, then province-wide to 13.9 by Q+5 | Kapuas only: 3.2 → 6.3 → 9.3 by Q+4; Kalteng mean 0.67 |
| Kalteng welfare, Q+1 | lowest (47.8) | — | — |
| Fiscal space | 29 | — | 35 |

- **a:** the livelihood follow-up appears.
- **c:** the dry-season episode CASE-0004-R hits less where prevention exists. The Kapuas follow-up "Api Menjalar dari Ladang" can then fire on Kapuas trust.

## Checks
| Check | Result |
|---|---|
| Godot tests | 116/116 (6 new in `test_crisis_cases.gd`) |
| Pipeline | 28/28 |
| Geography v2 | 44/44 |
| `validate_all` | OK |
| QA checklist | All passed, 0 runtime errors (`crisis_gameplay/qa_checklist.json`) |

One earlier QA run had a single transient click miss (Surabaya → Gresik after a correct hover). The harness drives the real cursor and keyboard; the miss did not reproduce.

## Not done / known gaps
- No new case facts or research.
- Price pressure is uniform in relative terms across regions: the cooking-oil weight in price indices and provincial palm-oil dependence are not modelled (documented limitation, shown in the panel).
- Burned area is not shown per province (no invented figures).
- The adat mechanic extends to other regions only with documented sources.
- Environment has no recovery dynamics (existing model).
- Windows build not verified on Windows.

## Next action
Save-slot menu. Population calibration (BPS key), which enables population-weighted national indicators.
