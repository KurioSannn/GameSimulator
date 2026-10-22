# 28 EXECUTION ROADMAP (deadline-driven)

Written 2026-10-05. **Submission deadline: 15 November 2026, which is 41 days away.** Both the APK and the EXE are required by the current guidebook.

## Why this roadmap exists

The research program in docs/04–06 and docs/16 (20 data domains, a full cultural knowledge base, 100+ validated cases) is a multi-month effort. With 41 days left, trying it in full before building the game would mean submitting no playable game. That would fail the rubric (Gameplay/UX 20%, Stability 20%) and the charter. Per the scope firewall (docs/01 §16) and "quality over apparent completion" (CLAUDE.md), the plan is:

> **Ship a stable, polished, honest vertical game first, then deepen the data.** Every number shown is either sourced or visibly labeled "belum terkalibrasi" (uncalibrated).

The long-term targets (100+ cases, broad culture KB, all domains) stay in place as the **master-library goal**. The competition build uses a curated, verified subset. This needs the human team's confirmation (see "Open decisions").

## Competition-build scope (target)

| Area | Competition build | Post-competition |
|---|---|---|
| Regions | All 514 kab/kota simulated every month; 38 provinces aggregated | same |
| Map | Real BIG boundaries; pan, zoom, select, hover; 4–6 overlays | finer LODs, labels |
| Real baselines | P0 set: population, area, IPM, poverty, PDRB (or per-capita), unemployment; disaster-risk index if obtainable | all domains in docs/19 |
| Cases | **12–20 researched cases**, geographically balanced across all 7 island groups, each with 3 choices and at least one follow-up chain | 100+ master library |
| Local wisdom | **3–5 researched mechanics** (candidates: subak, sasi, gotong royong, musyawarah, plus others found in research), each with a source → interpretation → mechanic record | broader KB |
| Systems | food/price/welfare/sentiment/trust, recovery, fiscal space, budget allocation (4–6 sectors), 3–4 policies with progression | tech trees |
| UX | Desktop 1920×1080: dashboard, map, region panel, case modal, advisor lines, Pusat Data, save/load, legacy screen | |
| Builds | Windows EXE (primary) + Android APK (compliance) | |

## Week plan

| Days (date range) | Milestone | Exit criteria |
|---|---|---|
| D1 (Oct 5) ✅ | Audit, architecture, sim core, save, case engine, region registry, schemas | 17 tests pass; benchmark recorded |
| D2–D4 (Oct 6–8) | **Map**: simplify BIG geometry → render mesh, hit test, pan/zoom, overlays; desktop main screen shell | Click any of the 514 kab/kota; 60 fps pan on dev machine |
| D3–D7 (Oct 7–11) | **P0 real data**: BPS key (human), population/IPM/poverty/PDRB by kab/kota → baseline.json with provenance; calibrate welfare_base, food, weights | ≥4 variables `REAL_OFFICIAL` for 514 regions; validation report |
| D5–D10 (Oct 9–14) | **Playable loop**: quarterly turn UI, case modal, budget allocation, policy cards, sentiment explanations, Pusat Data | A judge can play 4 quarters without guidance |
| D8–D18 (Oct 12–22) | **Content**: 12–20 cases + 3–5 local-wisdom mechanics researched and adapted; follow-up chains | Every case passes validate_all; geographic balance table |
| D15–D20 (Oct 19–24) | **Legacy** screen, save/load UI, autosave, settings; first **Windows export** + clean-machine test | EXE runs on a Windows PC with no installs |
| D18–D24 (Oct 22–28) | **Android export** smoke pass (thin input adaptation only) | APK < 250 MB installs and runs 1 quarter |
| D20–D30 (Oct 24–Nov 3) | Art/audio integration (Ananda, Cleo), Nara expressions, music, voice; UX polish | |
| D28–D35 (Nov 1–8) | Playtests (non-team players), balancing, performance on low-end Windows, bug bash | No crash in 3 full runs |
| D35–D39 (Nov 8–12) | Gameplay guide PDF, tools list, AI disclosure, source appendix, release candidates | Checklist docs/25 complete |
| D40–D41 (Nov 13–14) | Buffer; submit **before** 15 Nov | |

## Human actions needed (blocking or near-blocking)

1. **BPS WebAPI key** (webapi.bps.go.id/developer): register an account and app, and put the key in `.env` as `BPS_API_KEY=...` (gitignored). This blocks the P0 real baselines. Alternative: Dukcapil/other official downloads, which carry different definitions and must be labeled.
2. Confirm the **competition-build scope** above (12–20 cases instead of 100+ before submission).
3. **Windows test machine** for EXE clean-machine and performance tests, and **an Android device** for the APK.
4. Final game title in Bahasa Indonesia ("NUSANTARA: THE MANDATE" is English).
5. Registration (opened 21 Sep 2026 per poster) and administrative documents.
