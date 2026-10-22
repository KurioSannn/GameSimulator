# CASE-0005, nickel downstreaming and resource governance: execution report (2026-10-22)

Research record: `research/cases/CASE-0005.json`. Gameplay: `game/data/cases/CASE-0005*.json`. Decisions: D-069, D-070. Gaps: G-23 to G-28.

## Attempted
A researched, playable resource-governance case built on the existing case, effect, ledger, map and follow-up systems, with no new framework and no new simulation variable.

## Historical basis
Sources were retrieved on 2026-10-22; all are listed with URL and date in the research record.

| Fact | Source | Date | Quality |
|---|---|---|---|
| Ore below 1.7% Ni banned from export from 1 Jan 2020. Rationale: 698 Mt proven reserves ≈ 7.3 years of refinery supply. 11 smelters built, 25 under construction. | ESDM Siaran Pers 549.Pers/04/SJI/2019 | 2019-09-02 | official |
| EU WTO dispute DS592. Panel: inconsistent with GATT Art. XI:1 (30 Nov 2022). Indonesia appealed on 8 Dec 2022; under appeal. | WTO dispute page | 2022-12-08 | official (international) |
| Perpres 112/2022 bans new coal plants, except those integrated with resource-processing industry (≥35% emission cut within 10 years, operation until 2050 at most). | ESDM | 2022-09-23 | official |
| 2022 growth: Maluku Utara 22.94%, Sulawesi Tengah 15.17%, the highest in Sulawesi–Maluku–Papua. | BPS (Sulbar release, regional comparison) | 2023-02-06 | official |
| President: nickel exports rose from ≈US$2.1 bn/year before 2020 to US$33.8 bn after downstreaming. | Setkab | 2023-08-19 | official **claim** (year unstated) |
| Morowali estate in Kab. Morowali. 2,000 ha, US$6 bn planned, projected 26k direct / 80k indirect jobs. | Kemenperin | 2014-12-12, 2017-03-03 | official (projections) |
| Weda Bay industrial estate is a PSN (Maluku Utara). | KPPIP | undated | official (province only) |
| ITSS furnace explosion in IMIP, Kab. Morowali, 24 Dec 2023. 13 dead initially, 20 per Polda Sulteng (Feb 2024). Kemnaker inspectors deployed. | ANTARA, Kontan | 2023-12-24 to 2024-02-12 | news (quotes officials) |
| IWIP in Weda/Lelilef, Halmahera Tengah. ≈14,876 ha tree-cover loss 2001–2020 (Auriga data). Residents link floods to upstream clearing. | Mongabay | 2022-12-06 | news citing NGO data; labeled a reported concern |

- **Information at the decision date (early 2024):** see `information_available_at_decision` in the record.
- **Rejected or unverified:** HS 72 annual exports, a specific year for the US$33.8 bn figure, kab-level PDRB, health/air impacts, local employment shares, and the official status of the flood attribution.

## Final choices
The case is presented in month 31 (tick 30). The case event sets trust −2 in Morowali, a design translation of the explosion.

| Choice | Immediate | Delayed / ongoing | Trade-off |
|---|---|---|---|
| a, accelerate (keep the ban and the WTO appeal, fast-track smelters and captive plants under the Perpres 112 exemption) | trust −2 in both regencies | structural welfare +3 after 6 months; fiscal +4 after 9 months; environment −0.5/month for 12 months | most income and revenue; most environmental pressure and lowest local trust |
| b, conditional (K3 and environmental audits, stronger oversight, clean energy for new capacity) | fiscal −3 | services +3 and trust +2 after 3 months; structural welfare +1.5 after 9 months; fiscal +2 after 12 months; environment −0.2/month | best trust and services; costs now, smaller gains |
| c, moratorium on new smelters (existing ones operate) | trust +1 in Morowali | structural welfare +0.5 after 6 months; environment −0.1/month | least environmental pressure; least income |

**Follow-ups (both inspectable in the PEMICU block):**
- **CASE-0005-A "Sungai Keruh di Teluk Weda":** only if a was chosen, from month 40, and Halmahera Tengah's environment index is below 46.
- **CASE-0005-C "Investor Menunggu Kepastian":** six months after c.

Choice b never triggers A: the environment index stays ≥ 46 (tested).

## Multi-turn example
Full game content and seed; other cases answered "a". Full numbers: `case0005/multi_turn_full_game.txt`.

**Halmahera Tengah (82.02):**

| Choice | Structural welfare | Environment | Trust | Services | Sentiment | Follow-up |
|---|---|---|---|---|---|---|
| a | 55 → 58 at Q+3 | 50 → 44.0 at Q+4 | 49.5 at Q+4 | — | 48.2 → 39.9 at Q+6 | CASE-0005-A at month 40 |
| b | 56.5 at Q+4 | 47.6 | peak 52.9 | 48 → 51 | — | — |
| c | 56.5 at Q+5 (via the C follow-up, "reopen with strict conditions") | 47.0 at Q+6 | — | — | — | — |

- **a:** the audit chosen in CASE-0005-A then restores the environment to 46.
- **c:** the moratorium keeps environmental pressure lowest; the income gain arrives only through the follow-up.

**National:**
- **Fiscal space at Q+4:** a 44, b 36, c 38.
- **National welfare at Q+2, before any other case intervenes:** 53.137 / 53.138 / 53.137, a difference under 0.01. Two of 514 regions are affected, and the national indicators are equal-weighted (population uncalibrated). That is a true reflection of the model, not a defect.
- **Later national differences** (e.g. welfare 52.18 vs 51.57 at Q+6) mostly come from other cases (CASE-0003/0004) arriving at different times along each path. They are not CASE-0005 effects.

## Checks
| Check | Result |
|---|---|
| `validate_all` | OK, incl. the 3 case files and the research record |
| Godot tests | 122/122, incl. 6 new in `test_case_0005.gd` with golden master `case0005.json` |
| Earlier golden masters | CASE-0001 to 0004 unchanged |
| Pipeline | 28/28 |
| Geography v2 | 44/44 |
| QA checklist (real input) | all items passed, 0 runtime errors |
| In-game screenshots | `case0005/` |

**Fixed during the work (D-070):**
- the case window overflowed the screen, so choices 2 and 3 were not visible;
- a delayed revenue gain was labeled "Biaya".

## Calibration gaps
- **G-23:** employment and income by regency (`welfare_base` is a proxy).
- **G-24:** official environmental measurements (design pressure).
- **G-25:** fiscal contribution (design ±).
- **G-26:** Konawe and Obi estates (not modeled).
- **G-27:** HS 72 annual exports.
- **G-28:** kab-level PDRB and the provincial BRS.

National effects of two regions are small under equal weighting until population is calibrated (G-01).

## Next action
- Source Konawe/Obi (G-26) before extending the geography.
- Ingest the BPS kab PDRB (BPS key) to anchor `welfare_base` for 72.06 and 82.02.
