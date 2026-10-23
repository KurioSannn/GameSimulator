# DECISIONS LOG

## D-001
**Decision:** Real Indonesia is the game world.  
**Reason:** Local context and data integration are core differentiators.

## D-002
**Decision:** Main character is fictional and named Nara Adinata.  
**Reason:** Allows fictional choices/futures while preserving real Indonesian context.

## D-003
**Decision:** Starting state uses latest official public data available at the project snapshot.  
**Reason:** Grounding and traceability.

## D-004
**Decision:** Every modeled region is individually simulated every internal tick.  
**Reason:** Regional differences are core gameplay, not decorative data.

## D-005
**Decision:** Full game language is Bahasa Indonesia.  
**Reason:** Target audience and Indonesian cultural context.

## D-006
**Decision:** Story-driven sandbox.  
**Reason:** Allows curated cases while preserving player agency.

## D-007
**Decision:** Real-world cases are factual inputs; alternate player outcomes are simulation.  
**Reason:** Prevents historical misrepresentation.

## D-008
**Decision:** Save anytime, multiple saves, autosave, quicksave, offline.  
**Reason:** Simulation experimentation and competition reliability.

## D-009
**Decision:** Preserve actual data values/units in data layer; abbreviate only at UI.  
**Reason:** Data integrity.

## D-010
**Decision:** Claude Code chooses concrete software architecture from requirements.  
**Reason:** Keep implementation adaptive while protecting design constraints.

## D-011
**Decision:** Cultural research is broad and source-driven, but not every cultural item becomes a mechanic.  
**Reason:** Accuracy and cultural responsibility.


## Platform priority decision

**Locked:** Windows desktop `.exe` is the primary development, UX, and performance target. Android is a later compliance/export pass only if the official IT-CAS requirement remains APK + EXE. Core simulation architecture remains platform-agnostic.

**Reason:** The team wants to build a desktop strategy/simulation experience with map-heavy interaction and data-dense UI; desktop is the appropriate primary target. The official guidebook still states APK + EXE submission, so Android cannot simply be discarded at release without organizer clarification.

---

## D-012 — Engine version and renderer (2026-10-05, Claude Code; pending Galih review)
**Decision:** Godot 4.7.2-stable, GDScript only (no .NET), Compatibility renderer.
**Options:** Forward+, Mobile, Compatibility; Godot .NET.
**Why:** 2D-only game; widest Windows GPU coverage; same renderer on Android; no extra runtime for players.
**Risk:** a later Godot patch release; pin the version in docs/TECHNICAL_DESIGN_FINAL.md. **Test:** headless suite + Windows clean-machine export test.

## D-013 — Simulation entities are the 514 kab/kota; provinces are aggregates (2026-10-05)
**Decision:** Every kabupaten/kota has individual state and is processed every monthly tick. The 38 provinces and the nation are computed aggregates. Province-only data keeps `resolution=provinsi` and is never written into kab/kota fields as kab/kota data.
**Why:** satisfies D-004 at the finest official level with full map coverage. **Measured:** 1.6 ms per tick (M1 Pro).

## D-014 — Data-oriented simulation state (2026-10-05)
**Decision:** SimWorld holds structure-of-arrays (`PackedFloat64Array` per variable). Systems are central loops. There are no per-region Nodes or `_process`. Simulation code is plain `RefCounted` with no scene dependencies.
**Rejected:** a Node per region; `.tres` for dynamic state; ECS addons. See docs/TECHNICAL_DESIGN_FINAL.md §8.

## D-015 — Geographic primary key = Kemendagri code (2026-10-05)
**Decision:** `PP` for provinsi, `PP.KK` for kab/kota, sourced from BIG `kdpkab`. Names are labels. Display name = BIG `namobj`, except documented overrides for BIG abbreviations. Disputed or uncoded BIG features are never assigned to a region.

## D-016 — Uncalibrated variables are explicit (2026-10-05)
**Decision:** Until a sourced baseline exists, a variable carries `status: UNCALIBRATED` with a neutral game default. The UI must show "belum terkalibrasi" and must never style it as a statistic. Population weight falls back to equal weights while population is uncalibrated.
**Why:** lets the game be built and tested before data arrives without fabricating data (CLAUDE.md #14, docs/09 §9).

## D-017 — Formats (2026-10-05)
**Decision:** Research records, registry and game content are JSON validated by JSON Schema (`data/schemas/`). Saves are JSON envelopes with SHA-256, atomic write and `.bak`. The YAML in docs/templates is illustrative; JSON is canonical because it is parseable by both Godot and Python without extra dependencies.

## D-018 — Case conditions use a JSON DSL, not code (2026-10-05)
**Decision:** Case eligibility uses a schema-checkable JSON condition tree evaluated by CaseEngine. Selection uses the saved world RNG, so it is deterministic and replayable. Branching uses memory flags plus `case_choice` conditions.

## D-019 — APK treated as required; deadline-driven scope (2026-10-05) — APPROVED by Galih 2026-10-05
**Decision:** The current guidebook requires APK + EXE, so the Android export is scheduled (docs/28 D18–D24), not optional. The competition build targets 12–20 researched cases and 3–5 researched local-wisdom mechanics. The 100+ case master library and full culture KB continue as post-submission goals.
**Why:** 41 days to deadline; the scope firewall; quality over volume.

## D-020 — Strict four-layer data separation (2026-10-05, approved direction)
**Decision:** REAL source data (`data/raw`, immutable) → REAL normalized observations (`data/normalized/observations/*.jsonl`, one official value per row with provenance) → DERIVED game baseline (`game/data/baseline.json`, built only by documented calibration rules) → SIMULATED state (SimWorld/saves) → FICTIONAL content (briefings, dialogue, Nara). The UI shows REAL reference facts ("Data acuan") separately from simulated variables ("Kondisi simulasi").

## D-021 — Calibration policy (2026-10-05)
**Decision:** One reference period per variable: the latest period with ≥90% kab/kota coverage, so years are never mixed silently. Per-region starting-value status is `REAL | PROVINCE_PROXY | UNCALIBRATED`, and each is labeled in the UI. Zero denominators or missing values never become numbers. Duplicate observations for the same region/period are a hard error, so conflicts must be resolved explicitly. `sentiment_base` and `trust` stay neutral by design: no official measure of support for a fictional president exists, and deriving one from proxies risks stereotyping regions.

## D-022 — Simulated follow-up cases (2026-10-05)
**Decision:** Branch outcomes are `secondary_consequence` cases (IDs `CASE-NNNN-X`). They carry `simulated_context`, `origin_case`, and an empty `real_context` (`fact_class: NONE`), and the UI labels them "KONSEKUENSI SIMULASI · bukan peristiwa sejarah". The schema forbids them from containing real-fact lines. They may be state-dependent (e.g. CASE-0001-B opens only if recovery lags).

## D-023 — Golden-master regression for the reference case (2026-10-05)
**Decision:** `game/tests/golden/case0001.json` stores end-of-term outcomes and the case sequence for each CASE-0001 choice. Any model change that moves them fails the suite. Regenerate deliberately with `NUSANTARA_UPDATE_GOLDEN=1` and state the reason in the commit message.

## D-024 — Turn logic in a pure Session class (2026-10-05)
**Decision:** `Session` (RefCounted) owns sim, world and case engine and implements the quarter/case flow. The `Game` autoload wraps it with signals and saves. Why: full five-year playthroughs become testable headless.

## D-025 — Recurring flood model for G-11 (2026-10-05)
**Decision:** Floods occur per region per month with P = 0.35 × season × exposure/100; severity U(10,40) × exposure/100 is reduced by (1 − 0.75 × protection/100). Protection reduces severity only, so residual risk stays at least 25%. Exposure is 0 unless sourced (BNPB IRBI, pending) or revealed by a documented case (labeled case evidence). The seasonal profile is generic and UNCALIBRATED.
**Rejected:** a flat sentiment/welfare bonus for infrastructure (arbitrary); random floods everywhere from default exposure (would fabricate a hazard map).

## D-026 — Counter-based RNG for hazards (2026-10-05)
**Decision:** Hazard draws use hash(seed, tick, region, stream) (`SimRng`) instead of the sequential world RNG. Outcomes reproduce from (seed, tick, region); new systems don't shift existing outcomes; two policies face identical hazards (paired tests). Case selection keeps the sequential world RNG, whose state is saved.

## D-027 — Budget model: relative sector intensities (2026-10-05)
**Decision:** The player sets a spending level (0.8–1.2) and sector shares (infrastruktur, kebencanaan, layanan, pangan; must sum to 100). Effects depend on intensity = level × share / base_share, so they are unit-free. Real APBN 2026 figures enter later as `pool_rp` and verified base shares in `game/data/budget.json` (DERIVED from REAL observations via `build_budget.py`) with no equation change. Baseline funding is an exact equilibrium. Overspending drains fiscal space; at 0, overspending is blocked.

## D-028 — Exact save encoding, save schema v2 (2026-10-05)
**Decision:** Godot JSON is lossy for about 9% of doubles (measured). Saves therefore encode regional arrays as base64 float64 and other floats as hex (`SaveCodec`). Schema v2; v1 saves are migrated (their already-lost precision cannot be restored). Bare JSON numbers decode as ints.

## D-029 — Recurring cases and decision-time scopes (2026-10-05)
**Decision:** `trigger.recurring = {cooldown_ticks, max_occurrences}` with per-case history. Effect scope `where:<var><op><value>` resolves to an explicit region list when the decision is made, so later state changes do not retarget it.

## D-030 — Flood exposure calibrated from BNPB IRBI 2024; protection = additional (2026-10-06)
**Decision:** `flood_exposure` = 100 × IRBI 2024 flood risk score / 36 (linear; preserves BNPB's ranking). Regions absent from the IRBI flood table keep 0 and are labeled UNCALIBRATED (G-14). Because IRBI risk already includes regional capacity, `flood_protection` starts at 0 and represents protection added during the term (avoids double counting). CASE-0001 no longer sets exposure.
**Rejected:** treating IRBI absence as 0 risk silently; decomposing the score into hazard and capacity (scores are continuous, so not identifiable); harvesting InaRISK's internal HTML endpoint.

## D-031 — Exponential flood severity independent of exposure (2026-10-06)
**Decision:** Severity ~ Exp(mean 4), capped at 40, then mitigated. Exposure controls frequency only. Reason: with real exposure in 397 regions, the old severity (U(10,40) × exposure) collapsed national sentiment to 36 in an untouched term, and made every ordinary flood as damaging as the scripted 2020 Jakarta record. Coefficients remain UNCALIBRATED (G-13).

## D-032 — Flood model v0.5: BNPB event frequency + IRBI-derived severity scale (2026-10-06)
**Decision:** Events per region-month ~ Poisson(flood_frequency × seasonal share); impact = Exp(μ) × (0.5 + flood_risk_profile/100) × (1 − 0.75 × protection) × infrastructure resilience. `flood_exposure` is removed. The official IRBI score stays a REAL observation (`official_irbi_flood_score`); the 0–100 value is the DERIVED `flood_risk_profile`, never presented as an official percentage. Supersedes the occurrence part of D-025/D-030.

## D-033 — Gamma–Poisson (empirical Bayes) flood frequency (2026-10-06)
**Decision:** λ_i = (β·m_p + y_i)/(β + n_i), fitted by method of moments; the province prior is shrunk toward the national mean. No region gets λ = 0 by default (absence of records is not evidence of zero frequency). Labels: REAL (observed), PROVINCE_PROXY, UNCALIBRATED (national prior).

## D-034 — Severity normalization pending a population anchor (2026-10-06)
**Decision:** μ is derived (`build_hazard_calibration.py`) to preserve the validated national expected flood damage. The empirical rule (affected per event / population) activates when BPS population is ingested.

## D-035 — Access policy for BNPB data (2026-10-06)
**Decision:** Use the CKAN Action/DataStore API. Do not pass Cloudflare challenges on file downloads. Do not automate Google Drive downloads (robots.txt disallows them); a human downloads those folders.

## D-036 — Intersected decision-time scope `where:<cond>&in:<regions>` (2026-10-06)
**Decision:** Case effects that target "affected now" must be limited to the case's area. Found when real frequencies made CASE-0001-R relief apply nationwide.

## D-037 — Pinned production years for flood frequency (2026-10-06)
**Decision:** `flood_frequency` uses an explicit year list (`["2024"]`). Additional BNPB years become a *candidate*, evaluated by `compare_flood_frequency.py`. Production switches only after the comparison report is reviewed (edit `years`). Missing years are never zero.

## D-038 — BPS approval gate (2026-10-06)
**Decision:** BPS bulk ingestion is blocked per indicator until `data/calibration/bps_indicators.json` contains live-API-confirmed var_id, title, unit, year, level, region coding and domain scope, and `sample_checked=true` after a manual comparison with the published BPS table. No key is ever embedded or estimated.

## D-039 — Budget: three fiscal layers, fiscal units, policy crowding-out (2026-10-06)
**Decision:** REAL fiscal observations → DERIVED `budget.json` → SIMULATED national budget state. The contract is in `data/calibration/fiscal_structure.json` (no values). Fiscal Units: 100 FU = one year of the baseline program envelope; rupiah is a display conversion once `pool_rp` is REAL. Running policy commitments are paid from the envelope first: sector intensity = max(0, level − C) × share/base, spending = max(level, C). Transfers to regions and capital expenditure are not simulated until real data and mechanics exist.

## D-040 — Data-driven policy engine (2026-10-06)
**Decision:** Policies are JSON records run by one `PolicyEngine`. Phases are immediate/implementation/active; there is a running commitment, cooldown, mutual exclusion, prerequisites (shared condition DSL), regional eligibility filter, per-region response (`scale_by`), and one deterministic uncertainty multiplier per enactment. Effects act on upstream capacities so consequences flow through the causal model. Prototype policies are FICTIONAL game options with uncalibrated magnitudes. `cultural_basis` is a validated hook that must reference researched culture records.

## D-041 — Shared Conditions DSL; cases can react to policies (2026-10-06)
**Decision:** `Conditions` serves cases and policies; adds `policy_active` and `policy_enacted`.

## D-042 — Test runner must never hang (2026-10-06)
**Decision:** Suites that fail to load are reported as failures (`can_instantiate()` check).

## D-043 — No invented hazard models for unmodelled hazards (2026-10-06)
**Decision:** Earthquake recurrence is not simulated until calibration data exist (BNPB GEMPABUMI history and a severity anchor). Cases about such hazards use mechanics that exist (damage, recovery, services, trust, fiscal). Long-term risk reduction is recorded as memory flags for the legacy assessment, never as an in-term bonus.

## D-044 — Case template standard; gold-standard isolation (2026-10-06)
**Decision:** `tests/test_case_template.gd` applies the CASE-0001 standard to every `major_historical` case (sourced, dated facts; fictional briefing; ≥ 3 distinct simulated choices with divergent term outcomes; labeled follow-ups; decision gate). Each case suite loads only its own family, so adding cases never changes another case's golden master.

## D-045 — National commodity price pressure (2026-10-06)
**Decision:** `national.price_pressure` (0–1, default 0) multiplies every region's price target (×(1 + pp)) and decays 4% per month unless policy changes it. It represents national commodity or import price shocks (first used by CASE-0003) and flows into welfare and sentiment through the existing chain. At 0 the model is unchanged; all golden masters were unaffected.

## D-046 — Fire prevention capacity and scripted fire seasons (2026-10-06)
**Decision:** `fire_prevention` (0 at start) is built by enforcement, restoration or community governance. Fire-season episodes are scripted recurring cases (documented annual recurrence after 2015 per KLHK) whose impacts are scaled per region by prevention (`scale_by` gap mode). There is no random fire hazard model until calibration data exist (consistent with D-043). The dry-season calendar (July–October) is a labeled design assumption.

## D-047 — Case choices may enact policies (2026-10-06)
**Decision:** A choice can carry `enact_policy {policy_id, target}`; `Session.decide` enacts it through PolicyEngine (its costs, phases, prerequisites). Mechanics, including cultural ones, live in exactly one data record.

## D-048 — First local-wisdom mechanic (2026-10-06)
**Decision:** CULT-0001 (Dayak Ngaju handel group land preparation: deliberation, firebreaks, customary fine *jipen*; IPB 2017; later Pergub Kalteng 27/2019) → POL-KEBENCANAAN-API-ADAT. Fire prevention is scaled by trust as a proxy for community legitimacy; there is no livelihood cost; the effect is slower and less certain. The ritual component is excluded. The mechanic is labeled FICTIONAL abstraction; the record stays REAL description. Human cultural review is pending.

## D-049 — Case-template date precision (2026-10-06)
**Decision:** Real-fact dates use ISO at the precision the source provides (`YYYY-MM-DD` or `YYYY-MM`); a day is never invented. The template's identical-choice check includes `enact_policy`.

---

# Imported geography decisions (2026-10-22)

The validated geography baseline (BIG edisi Juni 2026, render LODs, area-unit audit) was built in a separate copy of the planning package (`~/Projects/nusantara_claude_package_desktop_first_v2`, commit `b6790d1`) and imported here when this repository was confirmed as canonical (2026-10-22). Its decisions are renumbered D-050 to D-057; the original numbers are noted on each.

## D-050
_Imported (originally D-012 in ~/Projects@b6790d1). Confirms existing **D-015** (Kemendagri code key); adds the BPS code as a crosswalk attribute._
**Decision:** Region primary key is the Kemendagri administrative code (`PP` provinsi, `PP.KK` kabupaten/kota). The BPS code is a crosswalk attribute (`kode_bps`), never a key.
**Reason:** Kemendagri is the legal authority for administrative codes (Kepmendagri 300.2.2-2138/2025), and BIG boundaries carry Kemendagri (PUM) codes. BPS codes diverge for the six Papua provinces (e.g. Kemendagri 91 = Papua, BPS 91 = Papua Barat), so mixing them silently would mis-join data. BPS-sourced statistics must be joined through `data/normalized/geography/crosswalk_bps_kemendagri.csv`.
**Date:** 2026-10-21 (Claude Code; conservative interpretation of docs/08 "use authoritative region codes as primary keys", open to team review)

## D-051
_Imported (originally D-013). Applies to the imported geography pipeline in `scripts/pipelines/geo/v2/` only._
**Decision:** The research pipeline is stdlib-only Python under `scripts/pipelines/geo/v2/`, with an immutable raw store `data/raw/<SRC>/<SNAP>/` plus SHA-256 sidecars, and snapshot IDs of the form `SNAP-YYYY-MM-DD`.
**Reason:** Reproducible on any machine without installs; satisfies the raw/processed separation and caching rules in docs/04 and docs/16.
**Date:** 2026-10-21

## D-052
_Imported (originally D-014). Restates existing **D-013** (514 kab/kota simulated, provinces aggregated); adds the treatment of BIG `TIPADM=6` fragments._
**Decision:** Simulation regions = 514 kabupaten/kota; province state is aggregated from them. BIG `TIPADM=6` unallocated island fragments (21 polygons) are rendered but are not simulation regions. "Wilayah terapung" secondary polygons belong to their parent kab/kota.
**Reason:** Matches the official Kemendagri/BPS count (416 + 98) and docs/07 per-region simulation; the fragments have no kab/kota code.
**Date:** 2026-10-21 (open to team review)

## D-053
_Imported (originally D-015)._
**Decision:** Render geometry is derived from the raw BIG kab/kota polygons (SRC-0001) with mapshaper 0.7.79, installed project-locally in `tools/geo/` (pinned; release dated 2026-10-06), using **Douglas–Peucker (spherical)** simplification. There are three LODs: **LOD1 = 1,000 m, LOD2 = 100 m, LOD3 = 40 m**, with coordinates at **1e-6°** (about 0.11 m), in both passes and in the output. Each LOD holds all 514 kab/kota (one feature per region), 38 provinces dissolved from that same layer, and 21 BIG `TIPADM=6` fragments.

**Method notes:**
- Multipart regions are exploded so `keep-shapes` protects every island.
- The build is two-pass. mapshaper simplification is non-destructive, so overlaps and self-crossings are repaired on re-imported, already-simplified geometry (pass B: `-clean gap-width=0`, re-dissolve, in-pipeline rounding with `fix-geometry`, clean again).
- Rounding only at output (1e-5°) created crossings, and 1e-3° destroyed about 46 % of island parts.

**Why Douglas–Peucker:** weighted Visvalingam was tried first and rejected. Its displacement is unbounded (24.8 km maximum at a 2 km interval), and the island component audit found 60–80 km² islands collapsed to 0.01 km² specks kilometres away at LOD1. Douglas–Peucker bounds every removed vertex to within the interval.

**Tolerance selection:** a documented selection rule, not a predeclared one. Its criteria were written down or refined after initial metrics had been observed, as recorded in `rule_history`. The rule picks the coarsest candidate that:
1. passes every hard validation check;
2. has mean displacement ≤ 0.5 px and Q3 displacement ≤ 1 px at the LOD's reference scale (viewport about 1,600 px; LOD1 ≥ 2,000 km views at 1,250 m/px; LOD2 300–2,000 km at 190 m/px; LOD3 at an 80 km reference view, 50 m/px);
3. for LOD1, has median area error ≤ 2 %;
4. leaves no *noticeable* source part (≥ 4 px long and ≥ 1 px mean width) displaced or lost.

All candidate measurements for both methods are kept in `research/reports/lod_tolerance_selection.json`.

**Reason:** an offline desktop game needs fast, valid, ID-preserving map geometry. The full-resolution source (2.2 GB) cannot be shipped, and the game must never call BIG at runtime.
**Date:** 2026-10-22

## D-054
_Imported (originally D-016). The group keys are identical to the existing `island_group` values in the region registry (same 7 keys, same province membership, verified 2026-10-22)._
**Decision:** Seven presentation-only navigation groups, stored in `data/design/navigation_groups.json` and keyed by Kemendagri province codes: `sumatera`, `jawa`, `bali_nusa_tenggara`, `kalimantan`, `sulawesi`, `maluku`, `papua`. They are a map navigation taxonomy, not an administrative level, and not written into the official region registry. The display name "Sumatera" uses Indonesian spelling, consistent with the official province names and the full-Bahasa-Indonesia rule; the team's request wrote it as "Sumatra".
**Reason:** team-defined grouping (2026-10-21); docs/08 says island labels must not overwrite the official hierarchy.
**Date:** 2026-10-22

## D-055
_Imported (originally D-017)._
**Decision:** BIG `LUASWH` is kept raw with its published label and declared unit "(HA)". It is annotated `UNIT_KM2_EVIDENCED` (legal/regulated area in km²) and never converted. `Shape_Area` is treated as planar square degrees and never used as an area. Polygon-derived area (`geom_area_km2`, WGS84 ellipsoidal equal-area) lives in a separate DERIVED column. Render layers carry no area fields.
**Reason:** three independent lines of evidence (`research/reports/2026-10-22_AREA_UNIT_INVESTIGATION.md`). Which area figure the game shows is a later, explicit choice.
**Date:** 2026-10-22

## D-056
_Imported (originally D-018)._
**Decision:** Kab. Sumbawa (OBJECTID 3424) is captured with `maxAllowableOffset=1e-7°` (maximum deviation about 1.1 cm) and stored under a distinct file name. BIG's server cannot return this feature at full resolution in any format (HTTP 500). The copy is reported as `recovered_features_not_full_resolution` and is not presented as untouched full-resolution data.
**Reason:** the alternatives were a missing region or a much coarser source; the deviation is about 2,000× below the 1:50.000 source accuracy.
**Date:** 2026-10-22

## D-057
_Imported (originally D-019). Consistent with the existing .gitignore policy (raw GeoJSON is not committed; checksums are)._
**Decision:** Git stores the code, catalogs, cards, normalized and processed data, render LODs, and the raw sidecars (`.meta.json`) and access log. It does not store the 2.2 GB of full-resolution BIG polygon pages, which stay on disk as the immutable raw store and can be re-fetched and verified by SHA-256.
**Reason:** repository size. Provenance is preserved by the sidecars and `scripts/pipelines/geo/v2/README.md`.
**Date:** 2026-10-22

## D-058 — Game map uses geography v2 meshes (2026-10-22)
**Decision:** The interactive map is built from the validated geography v2 render LODs (D-053), not the 2023-09 map files (removed). An offline step (`scripts/pipelines/game/build_map_lods.py`) projects with the existing game projection (equirectangular, lon0 118°E, standard parallel 2.5°S, 100 units/degree, y down), triangulates every polygon part with its holes using earcut 3.2.3 (checked per part), and writes `game/data/map/v2/kabkota_lod{1,2,3}.json` (metadata, provenance, region table) plus `.bin` (positions, region-index UVs, indices). Region identity is carried per vertex; fills are coloured through a per-region lookup texture. The game registry gains `kode_bps` from the validated crosswalk (SRC-0002).
**Why:** correct holes and enclaves, no dropped islands, newest official geometry, and fast native loading (`PackedByteArray.to_vector2_array`). A binary mesh is an engine asset derived from JSON-documented, sourced data, consistent with D-017's intent.
**Risk:** `.bin` must be included in the export filter (docs/30 §7; not yet verified).

## D-059 — LOD by on-screen scale, no hysteresis (2026-10-22)
**Decision:** LOD1 at ≥ 1,250 m per screen pixel, LOD2 at 187.5–1,250, LOD3 below 187.5. These are the documented view bands (≥ 2,000 km, 300–2,000 km, < 300 km at the 1,600-px reference viewport) expressed per pixel, so they are resolution independent. The LOD is a pure function of scale. No hysteresis: none is needed for stepwise wheel zoom, and none was observed in the measured zoom sweeps.

## D-060 — Own point-in-polygon test for map hit testing (2026-10-22)
**Decision:** `MapLod` uses an even-odd crossing-number test over all rings of a region, with per-ring bounding boxes. It does not use `Geometry2D.is_point_in_polygon`.
**Why:** the built-in was measured to report points outside metre-scale islet rings as inside (float32 ray to ~1e20), so islets were unselectable (71 of 5,950 fixture points). Regression test `test_tiny_islet_hit_test_regression`.

## D-061 — LOD2/LOD3 preloaded on worker threads after the first frame (2026-10-22)
**Decision:** LOD1 loads synchronously. LOD2/LOD3 are parsed on `WorkerThreadPool` threads once the first frame is drawn, and their meshes are built on the main thread. A LOD needed earlier waits for its task (never loaded twice). All LODs stay cached.
**Why (measured):** synchronous first use stalled ~105 ms (LOD3); with preloading the switch frame is 5.6 ms, and the first frame is not delayed (starting in `_ready` delayed it by ~370 ms). Memory with all LODs: 146 MB static, 113 MB video.

## D-062 — Exact per-region change attribution (SimLedger) (2026-10-22)
**Decision:** Each quarter, the simulation records for every tracked variable and every region the delta produced by each model system and each applied effect (immediate, delayed or ongoing). The ledger is saved (schema 4). The UI explains changes only from these recorded deltas.
**Why:** the panel and log must say what changed and why, and the explanation must equal the calculation. Sequential recording makes the causes sum exactly to the change. The ledger is observational, so outcomes and golden masters are unchanged.

## D-063 — National indicators: population weights only when complete (2026-10-22)
**Decision:** National means use population weights only if every region has population > 0; otherwise all 514 regions are weighted equally. The weighting in use is shown in the top bar and recorded in each quarter log entry.
**Why:** population is UNCALIBRATED (0 everywhere). The previous per-region fallback (weight 1 where missing) would have mixed real head counts with weight 1 once data arrives partially, silently over-weighting covered regions.

## D-064 — Quarter = 3 monthly ticks (kept) (2026-10-22)
**Decision:** The milestone brief mentions a "four-monthly-tick" quarter, but it also requires preserving the existing semantics. The quarter stays at 3 monthly ticks (60-tick, 20-quarter term, as locked in STATUS and docs/07).
**Why:** a calendar quarter is 3 months, and changing it would alter every calibrated rate, case timing and golden master. Conservative reading, documented here.

## D-065 — Uncalibrated starting data is hatched on the map; change mode uses a neutral palette (2026-10-22)
**Decision:** Regions whose starting value for the shown variable is UNCALIBRATED are drawn with diagonal hatching. The change view uses blue (down) and orange (up), not red and green.
**Why:** simulated values from neutral defaults must not look like measured statistics, and whether a rise is good depends on the variable (price vs welfare).

## D-066 — National drivers are attributed to their sources in every region (2026-10-22)
**Decision:** The national price pressure keeps a per-source decomposition (`SimWorld.drivers`, saved, schema 5). Each month, the share of every region's price change caused by the pressure is computed exactly and split across the sources (case event, decisions). Fiscal space and price pressure changes are also attributed per quarter.
**Why:** CASE-0003's main levers are national. Without this, regional price rises were explained only as "model", so the player could not see that the export ban lowered prices in Denpasar while costing Riau producers. Observational: golden masters for CASE-0001 to 0003 are unchanged.

## D-067 — Dayak Ngaju local-wisdom mechanic scoped to Kab. Kapuas (2026-10-22)
**Decision:** POL-KEBENCANAAN-API-ADAT is enacted only in Kab. Kapuas (62.03) by CASE-0004 choice c and CASE-0004-A choice b. The adat follow-up CASE-0004-C (trigger, effects, texts) is also scoped to Kapuas. Magnitudes are unchanged. The CASE-0004 golden master was regenerated deliberately: only choice c changes.
**Why:** CULT-0001 documents the handel/jipen practice in Desa Mantangai, Kapuas, and its sensitivity review states that it must not be generalized to all of Kalimantan Tengah or to every Dayak community. The previous province-wide target (14 kab/kota) contradicted that. Extending it to other regions needs documented sources first. Peat restoration remains province-wide (BRG priority province, Perpres 1/2016).

## D-068 — Follow-up triggers and choice reach are shown from the data (2026-10-22)
**Decision:**
- The case modal shows follow-up trigger conditions with their current values, generated from the same condition DSL the engine evaluates.
- Each choice shows a preview generated from its own effects: target regions, national levers, policy and its target, and horizon.
- No authored text is replaced.
**Why:** follow-ups must be inspectable and choices must reveal who bears costs and benefits before deciding. Deriving both from the data keeps the explanation consistent with the calculation.

## D-069 — CASE-0005 nickel downstreaming: documented regencies only, existing variables only (2026-10-22)
**Decision:**
- CASE-0005 applies direct effects only to Kab. Morowali (72.06) and Kab. Halmahera Tengah (82.02), the two regencies where sources place the processing estates (IMIP, IWIP).
- Konawe, Pulau Obi and nickel-mining-only regencies are not affected until sourced (G-26). Province-level BPS growth is shown as context, not distributed.
- No new simulation variable is introduced:
  - `welfare_base` (structural welfare, already "raised by long-term policy") stands in for industrial income;
  - `environment` for cumulative land clearing and emissions pressure;
  - `services` for inspection and health capacity;
  - `fiscal_space` for national revenue and enforcement cost.
- All magnitudes are design values and are disclosed in the case's `shock_note` and `consequence_notes` (gaps G-23 to G-25).
- `welfare_base` is now tracked by SimLedger so the panel attributes structural changes to the decision. This is observational: the CASE-0001 to 0004 golden masters are unchanged.
**Why:** no transparent kab-level baseline exists for industrial output, employment, pollution or tax. A new variable would imply measurement precision the evidence cannot support. Sourced geography avoids applying the policy to every nickel area in Sulawesi and Maluku.

## D-070 — Case window scrolls; fiscal gains are not shown as costs (2026-10-22)
**Decision:**
- The case window scrolls and is capped to the viewport between the top bar and the turn controls. Keys 1–n still choose.
- The fiscal line separates the immediate cost or gain from delayed fiscal effects ("ruang fiskal +4,0 setelah 9 bulan").
**Why:** CASE-0005's five sourced fact lines pushed choices 2 and 3 off screen in the real game. Choice a's later revenue displayed as "Biaya: +4,0", calling a gain a cost.

## D-071 — CASE-0006 NTT drought: only regencies with BNPB-recorded victims; mamar not a mechanic (2026-10-23)
**Decision:**
- Direct effects apply only to Kab. Sabu Raijua (53.20) and Kab. Kupang (53.01), the regencies with drought victims in the BPS/BNPB 2023 table (31,020 and 1,044 persons).
- Regencies that only declared emergency status are context only.
- The case event preserves the exposure ordering but is not proportional, because population is uncalibrated.
- Water access is represented by `services` and water infrastructure by `infrastructure`.
- *Mamar* (CULT-0003) is documented as informational only.
**Why:** a status declaration or a zone forecast is not a measured impact. The *mamar* evidence concerns erosion and agroforestry sustainability at village scale, not drought, so a mechanic would overstate it and generalize it to the whole regency.

## D-072 — CASE-0007 Papua primary care: province-level evidence applied as a labeled data adjustment (2026-10-23)
**Decision:**
- Direct effects apply only to Papua Pegunungan (95) and Papua Tengah (94), the two highest documented doctor gaps in 2023 (54.3%, 43.5%).
- When the case opens, services are reduced by 0.2 × the gap (−10.9, −8.7), uniformly within each province.
- These effects are labeled "Penyesuaian data kasus" via a new optional case field `trigger_label`, so the panel does not call them an event.
- A "Layanan Publik" map layer is added.
**Why:**
- The province is the finest reliable resolution retrieved.
- Without the adjustment, the neutral, uncalibrated services baseline (50 everywhere) would hide the documented gap.
- The 0.2 factor is a disclosed design choice.

## D-073 — New cases do not reuse national-scale policies for small targets (2026-10-23)
**Decision:** CASE-0006/0007 use direct, explicitly costed effects instead of POL-SOSIAL-BLT, POL-LAYANAN-DAERAH or POL-LAYANAN-PUSAT.
**Why:** those policies' monthly commitments are shares of the national budget envelope. For 2 to 16 regencies they would crowd out sector budgets nationwide (D-039) and greatly overstate the cost. Making policy costs scale with target size is a possible later improvement, not done here.

## D-074 — Fuel and cooking-oil price shocks share the national price-pressure driver additively, attributed by source (2026-10-23)
**Decision:**
- CASE-0008's fuel price adjustment uses the existing national `price_pressure` driver: +0.03 for a full adjustment, two steps of +0.015 for a phased one.
- Interaction rule with CASE-0003 (cooking oil): contributions add, are clamped to [0,1] at use, and decay together at the shared model rate.
- `SimWorld.drivers` keeps each source's share, so every region's price change is attributed to fuel and cooking oil separately (tested: exact sums, shares add up to the national value).
- Conditions on `price_pressure` (e.g. CASE-0003-C) read the combined value. This is documented and visible in the trigger block.
- Household support is a separate welfare effect, so it never mixes with the price channel.
**Why:** a second price variable would duplicate the price model, and nothing would say how the two combine. One additive driver with source attribution makes the interaction explicit and inspectable.

## D-075 — CASE-0008 scheduling and temporary support (2026-10-23)
**Decision:**
- CASE-0008 opens at tick 33 and its follow-ups at tick 36: quarters left free by every other case.
- The full-game sequence of all other cases is unchanged, tested for each choice. Follow-ups at tick 39 had delayed CASE-0003 and CASE-0004.
- Temporary support acts only on welfare, which reverts after the support ends. Services has no reversion, so a temporary programme on services would act forever, and it is not used.
- The case window shows multi-month fiscal effects as totals with timing.
**Why:**
- Only one case can open per quarter, and follow-ups outrank waiting majors.
- Expired assistance must not keep acting.
- A "−1,0" label for a 9-month drain understated the cost ninefold.

## D-076 — Baseline calibration from BPS table pages; model states labeled as such (2026-10-23)
**Decision:**
- `population` = BPS 2026 projection (table var 2790) and `welfare_base`/`welfare` = BPS IPM 2024 (var 413), for all 514 kab/kota. This follows the existing variable-map rules (`identity(pop_total)`, `identity(ipm)`).
  - Ingested by `scripts/pipelines/bps/ingest_bps_table_pages.py`, which parses the data cube embedded in the public statistics-table pages: no API key, cached raw with sha256.
  - Additive tables are checked against their kab/kota sums. Two inconsistent Papua province rows are dropped (G-38).
- National indicators become population-weighted (D-063, now satisfied).
- Variables that are model states, not measurements, get status `BY_DESIGN` with their documented reason, shown as "NILAI MODEL": price index, damage, flood/fire additions, food supply (recomputed), sentiment and trust (no official measure exists).
- Five variables without national kab/kota data stay `UNCALIBRATED` and visibly flagged: infrastructure, logistics, services, environment, food_capacity (G-39).
- The two follow-up welfare thresholds tuned to the old neutral 55 (CASE-0003-A, CASE-0004-A) are rebased to the province's calibrated start − 1, keeping their meaning.
- All case golden masters regenerated deliberately. Values change; no case's follow-up sequence changes, and the full-game case schedule is identical.
**Why:** real data where it exists, and an honest label where it does not. Removing "uncalibrated" labels without data would present design defaults as measurements.
