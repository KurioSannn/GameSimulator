# Execution report: Phase 0 (audit), Phase 1 (contracts), Phase 2 (geography, partial), sim core

Date: 2026-10-05 · Agent: Claude Code (Opus 5.5) · Reviewer: _pending (Galih)_

## 1. What was attempted

1. Full repository audit: all 28 docs, 7 prompts, 4 templates, the guidebook PDF and the poster.
2. Toolchain bootstrap: Godot, Python env, GIS tooling, git.
3. Phase 1 contracts: JSON schemas, source registry, provenance/status vocabulary, geographic key strategy.
4. Phase 2 geography: official boundary acquisition, region registry, crosswalk validation.
5. Highest-risk engineering early: full-region simulation core, benchmark, save system, case engine, tests.
6. One real case researched end-to-end (research record → game adaptation).

## 2. Audit findings

### Repository state at start
Documentation only. No code, no data, no assets, not a git repository, and no Godot installed. The specification set is thorough and internally consistent on core truths.

### Dependency map

```text
Competition rules ─► scope/roadmap ─► everything
Region registry (codes) ─► baseline data joins ─► calibration ─► meaningful simulation numbers
                       └─► map geometry join ─► map UI
Sim core ─► case engine ─► case content ─► story pacing
        └─► save system
Source registry ─► data ingestion ─► baseline.json ─► Pusat Data UI
Case research ─► case content ─► follow-up chains
Culture research ─► local-wisdom mechanics ─► policy/case choices
BPS API key (HUMAN) ─► most P0 socioeconomic baselines
```

### Contradictions and inconsistencies

| # | Finding | Resolution |
|---|---|---|
| C1 | Team size: the guidebook says "3 orang"; the poster says "1–3 orang Mahasiswa" | No impact (team has 3). Recorded. |
| C2 | The guidebook text says "IT-CAS 2025" inside the 2026 document | Already documented in docs/03; treated as a typo |
| C3 | Guidebook §8 gives "Stabilitas dan Performa" the description "Manfaat game untuk ke depannya" (which fits Dampak/Potensi); Dampak/Potensi has no description | Optimize for both literal readings: real stability/performance **and** future impact |
| C4 | Fee "Rp. 75.0000" in the guidebook vs Rp 75.000 on the poster | Administrative; for the team |
| C5 | **The APK is required** by the current rules, while the docs frame Android as "if still required" | The rules have not changed, so the APK is treated as **required** and scheduled (D18–D24), not optional |
| C6 | **Scope vs. time**: docs target 100+ validated cases, a full culture KB and 20 data domains; 41 days remain | Proposed competition-build scope in docs/28; **needs human confirmation**. Master-library targets are kept |
| C7 | docs/08 says "selection by click/tap"; desktop-first policy | Click only; "tap" read as a pre-desktop-pivot leftover |
| C8 | Working title "NUSANTARA: THE MANDATE" is English in a full-Bahasa game | Flagged to the team; not changed |
| C9 | Roles: docs/16 has ChatGPT as research lead; the master prompt asks Claude Code to research | Claude Code researches with sources; human review remains authoritative |
| C10 | BIG geometry edition (Sep 2023) is older than the Kepmendagri 2025 code baseline | Code sets match exactly (514); boundary-segment drift since 2023 is possible → gap G-04 |

## 3. What succeeded

- **Godot 4.7.2-stable** in `tools/` (sha256 of macOS binary: c7cccbf8…718ccf). Compatibility renderer chosen; see docs/TECHNICAL_DESIGN_FINAL.md.
- **Region registry**: 38 provinsi, 416 kabupaten and 98 kota. This matches the published Kepmendagri 300.2.2-2138/2025 totals exactly. Built from BIG's official feature service (field `kdpkab`) and cross-checked against a secondary transcription of the Kepmendagri list.
  - 3 name differences are recorded in `research/reports/validation/geo_region_crosswalk.md`. One is a truncation defect in the secondary source (16.02), which shows why it is used only as a cross-check.
  - 28 BIG features with no valid single kab/kota code (disputed or unassigned islands, Danau Moat, etc.) are kept raw and excluded from selection. Nothing was reassigned.
  - 5 kab/kota in Sulawesi Tenggara span several BIG feature rows; these were merged by code.
- **Official geometry download**: polite, sequential, with retry/backoff and per-file checksums in `data/raw/big/kabkota_2023-09/MANIFEST.json`. The download was still running at time of writing; see §5.
- **Simulation core**: 514 regions in structure-of-arrays form; one centralized monthly loop; causal chains damage → logistics → food → price → welfare → sentiment → trust, plus inter-regional food trade.
- **Benchmark** (M1 Pro, headless):

  | regions | median tick | max tick | 60-tick term | save size | serialize |
  |---:|---:|---:|---:|---:|---:|
  | 514 | 1.63 ms | 1.84 ms | 99 ms | 86 KB | 1.4 ms |
  | 2,056 | 6.5 ms | 7.3 ms | 392 ms | 344 KB | 5.7 ms |
  | 5,140 | 16.4 ms | 18.3 ms | 984 ms | 864 KB | 13.5 ms |

- **Save system**: atomic writes, `.bak` recovery, SHA-256 integrity, unlimited slots, quicksave and rotating autosave, region-snapshot guard.
- **Case engine**: condition DSL, deterministic weighted selection, memory flags for branching.
- **CASE-0001** (January 2020 Jabodetabek–Banten floods): status `researched`, with 6 sources and dated figures. Game adaptation has 3 choices with distinct trade-offs, verified by tests.
- **Tests: 17/17 pass.** The runner fails a test on any engine or script error; this was verified with a deliberately broken test.
- **Schemas** (7) and `scripts/validate_all.py`: all current data files pass.

## 4. What failed

| Item | Detail |
|---|---|
| BPS WebAPI | Needs a registered key (human action). www.bps.go.id returned 403 to the probe |
| Official Kepmendagri PDF | Not located on an official domain; secondary transcription used for cross-check only |
| DNS failures | djpk.kemenkeu.go.id, katalog.data.go.id, statistik.kkp.go.id, sigap.menlhk.go.id, warisanbudaya.kemdikbud.go.id, petabahasa.kemdikbud.go.id did not resolve from the research environment (possibly geo/DNS issues or domains moved after the 2024 ministry restructuring) |
| Global npm cache | Permission error in the user's `~/.npm`; worked around with a project-local cache (the user's cache was not modified) |

## 5. Skipped / deferred

- Map rendering (Phase 2b): waits for the geometry download to finish.
- All socioeconomic baselines: blocked on the BPS key. **Every simulation variable is `UNCALIBRATED`**, and the UI must label it as such.
- Culture KB: not started; the schema exists.
- CASE-0001 validation to `validated`: needs BNPB and BMKG primary documents archived.

## 6. Coverage achieved

| Domain | Coverage |
|---|---|
| Admin codes, kab/kota | 514/514 (100% of Kepmendagri 2025 totals) |
| Admin codes, provinsi | 38/38 |
| Boundaries | see MANIFEST (download in progress at report time) |
| Area (BIG `luaswh`) | 514/514, unit to be verified (G-03) |
| Socioeconomic baselines | 0 variables |
| Cases | 1 researched, 0 validated |
| Culture records | 0 |

## 7. Known gaps

See `research/reports/GAP_REGISTRY.md`.

## 8. Next actions

1. Finish geometry → simplify → render mesh → map scene with pan, zoom, select and hover (Phase 2b).
2. Human: BPS key. Meanwhile, ingest `luaswh` as `area_km2` once its unit is verified.
3. Desktop main-screen shell: top bar national indicators, map, region panel, case modal.
4. Case research batch 1: one case per island group, Java-capped.

## Addendum (same session, later)

- Boundary download finished: 550 files, 0 failures, 520 MB raw (gitignored; checksums in MANIFEST.json).
- Map geometry derived with mapshaper: lod0 has 514 regions and 104,959 vertices (1.6 MB); lod1 has 28,857 vertices. A first build silently lost one all-islands region (Kepulauan Seribu) to island filtering. This was caught by the 514-region assertion and fixed by moving island filtering into Python, where each region keeps its largest part.
- Desktop main screen implemented and verified in the real window via screenshots: map, overlays, hover, selection, region panel, case modal, quarter advance, quicksave/quickload.
- **Model bug found via screenshot and fixed**: the unshocked world drifted (prices to about 114, sentiment to about 58) because the defaults weren't an equilibrium. Food realization is now relative to the region's own infrastructure, and sentiment uses deviations from `sentiment_base`. The equilibrium test is now strict (±0.01).
- Tests: 18/18. Benchmark after the fix: 2.5 ms per tick for 514 regions (table above is pre-fix).
