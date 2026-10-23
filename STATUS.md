# STATUS

_Last updated: 2026-10-22 (Claude Code)._ **Submission deadline: 15 Nov 2026 (24 days).**

## Current phase
**Baseline calibration pass (2026-10-23)**:
- Population (BPS 2026 projection) and IPM 2024 now come from BPS for all 514 kab/kota (D-076).
- National indicators are population-weighted.
- Ten model-state variables are labeled "NILAI MODEL" with their documented reason.
- Still uncalibrated (no national kab/kota data found): infrastructure, logistics, services, environment, food_capacity (G-39).

**CASE-0008 fuel subsidy reform 2022 playable (2026-10-23)**: a national fiscal and distributional trade-off.
- Choices: hold prices / adjust with targeted transfers / phased adjustment with transport support.
- Fuel and cooking-oil price pressure are additive and attributed separately (D-074).
- Follow-ups are slotted so no other case is displaced (D-075).

Report: `research/reports/2026-10-23_CASE0008_FUEL_SUBSIDY_REPORT.md`.

**CASE-0006 (NTT drought 2023) and CASE-0007 (Papua primary care) playable (2026-10-23)**:
- all seven island groups are now covered;
- direct effects only where sources document exposure (D-071, D-072);
- *mamar* researched and kept informational (CULT-0003);
- new "Layanan Publik" map layer.

Report: `research/reports/2026-10-23_CASE0006_0007_REPORT.md`.

**CASE-0005 nickel downstreaming playable (2026-10-22)**:
- first resource-governance case and first Maluku coverage;
- 12 dated sources (ESDM, WTO, BPS, Setkab, Kemenperin, KPPIP, ANTARA, Kontan, Mongabay);
- effects only in Kab. Morowali and Kab. Halmahera Tengah;
- choices: accelerate / conditional / moratorium;
- two condition-triggered follow-ups (D-069, D-070).

Report: `research/reports/2026-10-22_CASE0005_NICKEL_REPORT.md`.

**Crisis cases integrated (2026-10-22)**: CASE-0002/0003/0004 play through the regional loop.
- National price pressure is attributed per region to its sources (D-066).
- The adat mechanic is scoped to its documented location, Kapuas (D-067).
- Follow-up triggers and choice reach are visible (D-068).
- New overlays: trust, environment, fire prevention.
- Save schema 5.

Report: `research/reports/2026-10-22_CRISIS_GAMEPLAY_REPORT.md`.

**Regional simulation integration complete (2026-10-22)**:
- decisions → per-region consequences over all 514 kab/kota;
- exact cause attribution per region (SimLedger, D-062);
- map change view and uncalibrated hatching (D-065);
- region panel "what changed, why, what is scheduled";
- event log (L);
- national indicators explicitly equal-weighted until population is calibrated (D-063);
- save schema 4.

Docs: docs/31; report: `research/reports/2026-10-22_REGIONAL_SIMULATION_REPORT.md`.

**Map integration vertical slice complete (2026-10-22)**: the game map now uses the validated geography v2 (BIG edisi Juni 2026, three LODs, holes and small islands kept), selects by canonical Kemendagri ID, and was measured in the real engine (`research/reports/2026-10-22_MAP_INTEGRATION_REPORT.md`, docs/30). Geography v2 imported from the planning copy (D-050–D-057).

**Milestone 2 complete + real flood calibration**: flood frequency from BNPB 2024 event history (all 514 kab/kota, D-033), severity scaled by official IRBI risk (D-032). BPS socioeconomic data still blocked on the API key. Government hosts reachable again from this machine since 2026-10-05 ~19:30 UTC, except DJPK and the data.go.id proxy. Roadmap: `docs/28_EXECUTION_ROADMAP.md`.

## Built and tested
- Manual QA checklist automated in the real engine (`--qa-checklist`): 6/6 items, all checks passed, 0 runtime errors (re-run 2026-10-22 after regional integration); WASD panning fixed
- Godot 4.7.2 project in `game/` (Compatibility renderer, desktop 1920×1080)
- Simulation core: 514 kab/kota, monthly tick, quarterly turn, 60-tick term, causal chains, deterministic RNG. **1.6 ms per tick**
- Effect queue (delay/duration/scope), case engine (condition DSL, branching memory)
- Save system: unlimited slots, quicksave, autosave rotation, atomic write, `.bak` recovery, checksum, snapshot guard
- Region registry 38/416/98 from official BIG + Kepmendagri-2025 cross-check
- CASE-0001 (2020 floods, Jawa), CASE-0002 (2018 Palu, Sulawesi), CASE-0003 (2022 cooking-oil crisis, Sumatera + national; first non-disaster case), CASE-0004 (2015 peat fires, Kalimantan; first local-wisdom mechanic CULT-0001), CASE-0005 (nickel downstreaming 2020–2024, Morowali + Halmahera Tengah), CASE-0006 (NTT drought 2023, Sabu Raijua + Kupang), CASE-0007 (primary-care access, Papua Pegunungan + Papua Tengah), CASE-0008 (fuel subsidy reform 2022, national), all researched; case template suite; registry research/cases/CASE_REGISTRY.md
- 140/140 Godot tests + 28/28 pipeline tests + 44/44 geography v2 tests; golden master; schema validation passing (incl. 514 real area observations)
- Recurring flood system (G-11), budget system (4 sectors + spending level + fiscal space), counter-based hazard RNG, recurring cases, exact save encoding (schema v2)
- Data pipeline: observation schema, BPS WebAPI connector (strict parser), calibration builder (REAL/PROVINCE_PROXY/UNCALIBRATED per region), `scripts/run_pipeline.sh`
- CASE-0001 gold standard: 3 simulated follow-up branches (one state-dependent), regression suite + golden master
- **Playable prototype screen**: real BIG map (edisi Juni 2026, geography v2 meshes, D-058) of all 514 kab/kota with three LODs switched by on-screen scale (D-059), background preloading (D-061), correct holes/enclaves, per-region shader colours; pan, zoom, hover, select by canonical ID (own hit test, D-060); panel shows Kemendagri ID, BPS code and parent province with a province view button; 6 overlays, region panel with sentiment explanations and fact-class tags, case modal, quarter turns, quicksave/quickload

- **Policy + budget system**: data-driven PolicyEngine (6 prototype policies, 14 categories), regional targeting/response, delayed phases, commitments crowding out sector budgets, fiscal ledger, policy UI (P), save schema v3

## Ready, waiting on human input
- BPS workflow (check → inventory → sample → bulk, approval-gated) — needs `BPS_API_KEY` in `.env`
- Multi-year BNPB frequency — needs the 2002–2023 Drive files in `data/raw/bnpb/drive_manual/<year>/` (index: `research/sources/bnpb_yearly_index.md`)

## In progress / next
- Save/load menu UI (slot list), legacy screen, budget allocation + policy cards
- Case research batch 1 (one per island group)

## Blocked
- **Windows export not verified**: no Windows machine, export preset or export templates on this machine. The export filter must include `data/map/v2/*.bin` (docs/30 §7). All map measurements so far are macOS/M1 Pro.
- DJPK and the data.go.id proxy still time out from this machine (probe log)

## Blocked (human action)
- **Download BNPB 2002–2023 Drive folders** (G-15) into `data/raw/bnpb/drive_manual/<year>/`
- **BPS WebAPI key**: still useful for poverty/PDRB/unemployment; population and IPM no longer need it (D-076)
- A Windows test PC and an Android device

## Not yet built
Save-slot menu UI, policy UI, Pusat Data, legacy screen, culture KB, further cases, art/audio, Windows/Android exports.

## Locked (unchanged)
Real Indonesia; fictional president Nara Adinata; full Bahasa Indonesia; latest official data; every region simulated every monthly tick; 5 years / 20 quarters / 60 ticks; offline; save anytime with multiple saves, autosave and quicksave; Godot + GDScript; desktop-first, with APK as a compliance target.
