# Regional Simulation Integration: execution report (2026-10-22)

Contract: `docs/31_REGIONAL_SIMULATION.md`. Decisions: D-062 to D-065.

## Attempted
Connect decisions → regional consequences → map, panel, national indicators and the event log, with per-region attribution, explicit national weighting, and schema-4 saves.

## Succeeded
- **End-to-end flow, verified in the real windowed game (macOS, M1 Pro):**
  - start;
  - decide CASE-0001 (a, b or c);
  - advance a quarter, which simulates 3 months for all 514 regions;
  - regional values change;
  - the map recolours (values or change mode);
  - the panel explains start → now and the causes;
  - the top bar shows national aggregates and ▲▼;
  - F5, advance, F9 restores exactly.
  - Screenshots are in `research/reports/regional_simulation/`.
- **Different choices give different outcomes.** For example, with choice a, DKI trust gets +4 "segera" and the damage relief arrives "tertunda", while choice b has neither. Choice c gives the follow-up case "Warga Menagih Janji" (screenshot 03).
- **Exact attribution:** the sum of causes equals the change for every region and variable (max error < 1e-9). The ledger does not alter outcomes, and all 4 golden masters are unchanged.
- **National weighting:** equal-weighted over 514 regions, because population is uncalibrated; this is displayed and logged.
- **Uncalibrated starting data:** hatched on the map, BLM KALIBRASI in the panel.
- **Save schema 4:** ledger + event log, with v3 migration.

## Checks run
| Suite | Result |
|---|---|
| Godot headless | 110/110 (101 existing + 9 new in `test_regional_sim.gd`) |
| Pipeline (Python) | 28/28 |
| Geography v2 | 44/44 |
| `validate_all.py` | OK |
| QA checklist (windowed, real input) | 6/6 items, all checks passed, 0 runtime errors (`regional_simulation/qa_checklist.json`) |
| Ledger cost | 13.8 ms/quarter with the ledger vs 10.5 ms without (20 quarters, all cases) |

## Failed / fixed during the work
- **QA checklist islet clicks.**
  - **Symptom:** clicks on 2–212 m² islets failed when the window gave an odd viewport width (1979 px). The cursor lands on a whole physical pixel, up to half a pixel off centre, which is more than the islet.
  - **Same failure on the previous commit:** reproduced there at the same viewport, so it is not a regression.
  - **Fix:** the harness now re-centres the camera on the pixel the cursor reached. The checklist then passed fully.
- **Region panel clipped** by the new baseline column (seen in the screenshot). Widened to 460 px.

## Skipped (out of scope by the brief)
Android, new data ingestion, new case research, the 100-case library, a UI redesign. The province-level aggregate view and a full history beyond the last quarter are not built; the ledger keeps one quarter, and the log keeps 40 entries.

## Known gaps
- **Population is uncalibrated,** so national indicators are equal-weighted, not population-weighted. This switches automatically once every region has population data (D-063).
- **Most variables start UNCALIBRATED;** model coefficients are design assumptions (`sim_params.json`). The explanations are exact with respect to the model, not empirical claims.
- **Save size** about 270 KB (was about 115 KB) because of the per-region cause arrays.
- **Windows build still not verified** on Windows.

## Next action
Save-slot menu UI. Calibrate population (BPS key) so national weighting becomes population-based. Further cases use the same attribution without extra code.
