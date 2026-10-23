# CASE-0008 fuel subsidy reform: execution report (2026-10-23)

Research record: `research/cases/CASE-0008.json`. Gameplay: `game/data/cases/CASE-0008*.json`. Decisions: D-074, D-075. Gaps: G-34 to G-37.

## Sources and the facts they support
| Source | Date | Facts |
|---|---|---|
| ESDM Siaran Pers 340.Pers/04/SJI/2022 | 2022-09-03 | Pertalite Rp7,650 → 10,000; Solar Rp5,150 → 6,800; Pertamax Rp12,500 → 14,500; effective 14:30 WIB |
| Setkab, presidential statement | 2022-09-03 | Subsidy and compensation budget Rp152.5 → 502.4 trillion (government estimate); ">70% enjoyed by the well-off" (claim); BLT BBM Rp12.4 trillion (Rp150,000 × 4 months, 20.65 million families); BSU Rp9.6 trillion (Rp600,000, 16 million workers ≤ Rp3.5 million); 2% DTU Rp2.17 trillion |
| DJPb Kemenkeu, KPPN Parepare | 2022-09-14 | Rp24.17 trillion redirected to social protection; BLT for the poorest and most vulnerable 30%, in two installments; 2% DTU for social aid, jobs, and transport/ojek/fisher/UMKM support |
| BPS inflation release | 2022-10-03 | Sep 2022: 1.17% m-to-m, 5.95% y-on-y; transport group +8.88%; core 0.30%; 88 of 90 CPI cities with inflation. Context only, not causal attribution, not extrapolated |

**Failed:** the Kemenkeu article of 19 Sep 2022 (host timed out). DJPb is used instead, and the failure is logged.

## Choices
| Choice | Reach | Immediate | Delayed / expiry | Trade-off |
|---|---|---|---|---|
| a, hold prices | national fiscal | none visible | fiscal −1/month for 9 months | protects every household now; drains the budget and keeps an untargeted subsidy |
| b, adjust and target compensation | price: all 514 regions; BLT: all, larger where simulated welfare is lower | price pressure +3%; fiscal −2.4 (package); BSU welfare +0.4 | BLT +0.6/month for 4 months, then ends; savings +0.8/month for 9 months from month 2 | fastest fiscal relief and protects the poorest, but the largest price shock, and support is temporary |
| c, phased with transport/livelihood support | all regions, untargeted | price pressure +1.5%; fiscal −1 | second +1.5% after 6 months; welfare +0.3/month for 6 months, then ends; savings +0.4/month for 9 months | smaller shocks, but slower budget relief and less protection for the poorest |

**Follow-ups:**
- **CASE-0008-A:** tick 36, after a, if fiscal space is below 48.
- **CASE-0008-B:** tick 36, after b, while one BLT month remains, if the mean price is above 101.

The full-game sequence of all other cases is unchanged for each choice (D-075).

## Example
Full game and seed; other cases answered "a"; decided at tick 33 with fiscal space 33. Full numbers: `case0008/multi_turn_full_game.txt`.

| Choice | Q+1 fiscal | Q+1 national price | Q+1 national welfare | Q+3 fiscal |
|---|---|---|---|---|
| a | 30.0 | 101.7 | 53.09 | 31.0 (after a forced late adjustment in CASE-0008-A, with no package ready) |
| b | 32.2 | 103.8 | 54.09 (BLT cushions the price rise) | 38.8 |
| c | 32.8 | 102.7 | 53.53 | 38.2 |

- **b's welfare:** 54.13 at Q+2, then 53.09 at Q+3 once support ends.
- **Regional view:** the Sabu Raijua panel attributes "+3,0 tekanan harga nasional: Keputusan «Subsidi BBM…»: Naikkan harga…" separately from the BLT welfare effects ("efek segera" / "efek berlanjut").
- **Interaction:** when CASE-0003 later opens, the cooking-oil share is listed as its own cause, e.g. Denpasar under c: fuel +2.40 and cooking oil +4.66 in one quarter.

## Checks
| Check | Result |
|---|---|
| `validate_all` | OK |
| Godot tests | 140/140, incl. 8 new in `test_case_0008.gd` + golden master |
| Earlier golden masters | CASE-0001 to 0007 unchanged |
| Pipeline | 28/28 |
| Geography v2 | 44/44 |
| In-game screenshots | `case0008/` |

## Fixed during the work
- Choice c's transport support on `services` left a permanent +1.2 after the programme ended (services has no reversion). Removed; support now acts on welfare only.
- Follow-ups at tick 39 delayed CASE-0003/0004 in the full game. Moved to tick 36.
- The case window understated multi-month fiscal costs. It now shows totals.

## Uncalibrated
- Subsidy allocation by household and region (G-34).
- Regional pass-through (G-35).
- BLT/BSU targeting by region (G-36): welfare-gap proxy.
- Compensation effectiveness and the rupiah → fiscal_space mapping (G-37).
- All magnitudes are design values; no rupiah figure is converted into game units.

## Next action
- Kemenkeu APBN KiTa / LKPP 2022 for the official outturn.
- Susenas fuel expenditure by province, to replace the uniform pass-through if it becomes available.
