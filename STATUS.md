# STATUS

_Last updated: 2026-11-23 (Claude Code, trackpad/mouse controls + case re-verification)._ **Submission deadline recorded by the project: 15 Nov 2026.**

## Current phase
**Trackpad/mouse controls and case re-verification (2026-11-23; user request)**:
- Map navigation no longer requires click-and-hold. Two-finger trackpad swipe pans; pinch, Ctrl/⌘+scroll and the wheel zoom toward the cursor; Shift/horizontal wheel pans; touchscreens get two-finger pinch/pan. Shared `MapNavInput` serves both cameras. New setting GULIR / TRACKPAD; always-visible +/−/⌂ buttons.
- CASE-0009…0020 audit: 50 cited URLs, most 404/unreachable; the registry listed different topics than the files contained. Six topics re-researched with sources read on 2026-11-23 and now playable: CASE-0011, 0013, 0014, 0015, 0016, 0020 (14 major cases in game). Six records quarantined (status back to `candidate`).
- Capacity: one decision per quarter (20 slots). New cases use story_priority 8, so the original eight always appear; 2–3 new cases are skipped per playthrough. **Team decision needed** on decisions per quarter.
- Tests 167/167. Report: research/reports/2026-11-23_CONTROLS_AND_CASE_REVERIFICATION_REPORT.md.

**Profile/avatar/frame-spacing fixes implemented (2026-11-20; user authorized after audit)**:
- Shared outer inset 36 versus slice 24; banner controls clear their edges, case inner width follows actual frame margins, and disabled buttons retain readable paper styling.
- Framed, aspect-preserving HUD/profile portraits. One alpha-cropped character stage anchors feet to a soft contact shadow; separate blue ellipse removed from profile composition.
- Clear player-name field with Save/Cancel/Enter, dirty/success feedback and synchronized empty-name normalization. Repeated profile identity/mandate fields reduced; fonts and map integration retained.
- 82 final states / 42 screenshots at 720p/1080p and 100%/110% text: zero unclipped button safe-area/viewport candidates. Profile observations 20/20; headless regression 155/155; all 27 cases/eight programs 318/318; native flows/assets 125/125. No window-QA runtime errors. Report: research/reports/2026-11-20_UI_SPACING_PROFILE_FIX_REPORT.md.

**Profile/avatar/frame-spacing audit completed; audit made no production edits (2026-11-20; user requests audit first)**:
- 82 UI states across 1280×720 / 1920×1080 and 100% / 110% text; 42 screenshots. No unclipped buttons outside panel/window rectangles, but repeated candidates intrude on the conservative decorative-frame safe area.
- Shared frame inset 20 versus slice 24; HUD identity uses 12 versus 24. Portrait crop is forced to a square; profile character/platform have a measurable gap.
- Player-name editing already persists locally; discoverability and save feedback are missing. Empty-name normalization does not update the field immediately; avatar editing is not implemented.
- Fixture saves/preferences isolated; 22/23 production-file SHA-256 unchanged. hud.gd changed elsewhere in the workspace during the audit; findings refer to captured runtime evidence. Findings and proposed priority: research/reports/2026-11-20_UI_SPACING_PROFILE_AUDIT_REPORT.md. No new implementation decision adopted.

**Game UI and concise information flow implemented (2026-11-20; user direction)**:
- Kenney CC0 paper/metal frames, textured buttons, medallion/hexagon navigation, live-map menu, three resource readouts and one agenda.
- Two active font families: Bree Serif headings and Alegreya Sans Medium/Bold body/controls/numbers. Explicit body binding prevents engine font fallback; 22-unit minimum on 1440×810 canvas.
- Region default shows two indicators; full data/provenance remains optional. Decisions show details for the selected option, with separate confirmation. Repeated APBN/simulation notices and technical timing text removed from normal play per user request.
- Initial map: 49 → 10 text blocks; city detail + HUD: 81 → 19; unselected decision: 48 → 15. Map renderer/data remain outside this UI task.
- Evidence: research/reports/2026-11-20_UI_IMPLEMENTATION_REPORT.md; ui_implementation_20261120/{final,flow,clarity}. Regression 154/154; extended case/program QA 318/318; mouse/keyboard flow and asset checks 128/128. No runtime errors in either window QA suite.

**UI/text density audit completed; implementation stopped per user direction (2026-11-20)**:
- Captured 13 current Godot UI states at 1600×900 / 1280×720. Detail city + HUD increases from 49 to 81 text blocks at 1600; at 1280, 45/48 decision-panel text blocks have estimated effective font size below 12 px (audit heuristic, not glyph-height measurement).
- Main findings: simultaneous information levels, repeated agenda/indicators, competing action emphasis, tiny text despite unused space, and visually stacked modal backgrounds. No significant text-bounds overlap candidates in the sampled states.
- Creator sources, licenses and original previews reviewed for Themey, Kenney Adventure/Fantasy Borders, and Maaack Game Template. No package installed or selected; no production UI changes or new mockup integration.
- Isolated audit world hash unchanged. Report: research/reports/2026-11-20_UI_DENSITY_AUDIT_REPORT.md; evidence: research/reports/ui_audit_20261120/inventory.json; sources: research/sources/ui_library_review_2026-11-20.json.

**Expanded map assets and atmosphere implemented (2026-11-19; user follow-up)**:
- 48 pinned Kenney CC0 models: 12 houses, 12 buildings/towers, 18 nature variants, four road tiles and two lamps. All variants are used, with source URLs, notices and checksums.
- 9405 decorative props in 48 model batches: 2647 houses, 62 midrises, 98 towers, 1338 road tiles, 564 lamps and 4696 nature props. Each of 514 regions has its own fitted core; block rotation, scale and roof colors vary.
- 36 cloud clusters in one additional batch; coherent silhouettes, three altitude bands, drift and camera-dependent size. Original shaders add foliage gusts, subtle facade glints, ground/water atmospheric shading, shallow-water caustics and broken coastal foam.
- Shared catalog drives asset acquisition, reproducible placements and runtime. Full GIS/state coverage, analytical layers, reduced motion and offline runtime retained.
- Evidence and verification: research/reports/2026-11-19_MAP_ASSET_EXPANSION_REPORT.md; research/reports/map_expansion_20261119/final/qa.json.

**Low-poly map remake implemented (2026-11-19; explicit user request)**:
- Curated eight Kenney CC0 models from a pinned GitHub mirror; 2298 decorative props in eight MultiMesh batches, island labels, ambient clouds, tree sway and active-case markers.
- Coastal foam/shallow-water display field built reproducibly with SciPy from the unchanged GIS triangulation. It is artistic decoration, not measured bathymetry or land cover.
- 3D landscape is the normal starting view; T retains 2D. Analytical layers hide decorative props and retain the simulated indicator values and calibration labels.
- Camera framing and selection lift refined; all 514 canonical regions remain available. Window QA verifies 3D mouse selection, data context, overlays, reduced motion and unchanged world/RNG.
- Report and source review: research/reports/2026-11-19_LOW_POLY_MAP_REMAKE_REPORT.md; research/sources/map_visual_research_2026-11-19.json.

**Figma UI integrated into the Godot runtime (2026-11-15)**:
- Offline start/continue/save menu; profile, statistics, persisted device settings, decisions, quarterly report, and shared Detail Wilayah are functional native Godot controls.
- Region/province/island-group/national scopes read the current world; official facts retain resolution, units and source metadata. No illustrative Figma statistic is inserted into simulation state.
- Real GIS geometry and all 514 simulation entities retained, including case/report mini maps.
- Fonts and artwork bundled locally. Default map is 2D, with existing 3D mode available via T.
- Windows launcher: Mainkan NUSANTARA.cmd. Source metadata reproducible with scripts/pipelines/game/export_ui_sources.py.
- Headless regression and real mouse/keyboard/window QA recorded in the integration report.

Report: research/reports/2026-11-15_FIGMA_GODOT_INTEGRATION_REPORT.md; UI evidence: research/reports/ui_runtime_20261115/flow/qa_ui.json.

**General region-detail Figma component complete (2026-11-15; user clarification: every map context)**:
- One shared Detail Wilayah component with region identity, resolution, indicators, baseline/source metadata and policy context; Jawa Timur is an example instance.
- 58 map triggers across national, case, report and detail-map contexts reset all 38 selected-region fields. Six sequential read-back transition checks passed.
- Province, city and island-group examples; missing values stay blank and national report metrics are not copied into regional fields.
- Four pre-change map-context frames archived. Godot integration and full GIS hit testing remain outside this Figma change.

Report: `research/reports/2026-11-15_REGION_DETAIL_UI_REPORT.md`; evidence: `research/reports/2026-11-15_REGION_DETAIL_UI_EVIDENCE.json`.

**Figma desktop UI audit complete (2026-11-15; design/prototype only)**:
- Seven NUSANTARA frames corrected in place; originals archived in the same Figma file.
- Offline start menu, quarterly/monthly labels, profile tab, decision-card consistency, readable captions, and explicit sample-data labels.
- Navigation connected; complete report fixture restricted to confirmed choice B. Static read-back reaction evaluation: 6/6 branches passed.
- Existing art, fonts and palette retained; small local button/badge component foundation added.
- Godot runtime integration, interactive playback, window-resize QA, save/load and settings persistence remain unverified by this audit.

Report: `research/reports/2026-11-15_FIGMA_UI_AUDIT_REPORT.md`; node/action evidence: `research/reports/2026-11-15_FIGMA_UI_AUDIT_EVIDENCE.json`.

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
