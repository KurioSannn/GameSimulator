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

## D-012
**Decision:** Region primary key is the Kemendagri administrative code (`PP` provinsi, `PP.KK` kabupaten/kota). The BPS code is a crosswalk attribute (`kode_bps`), never a key.
**Reason:** Kemendagri is the legal authority for administrative codes (Kepmendagri 300.2.2-2138/2025), and BIG boundaries carry Kemendagri (PUM) codes. BPS codes diverge for the six Papua provinces (e.g. Kemendagri 91 = Papua, BPS 91 = Papua Barat), so mixing them silently would mis-join data. BPS-sourced statistics must be joined through `data/normalized/geography/crosswalk_bps_kemendagri.csv`.
**Date:** 2026-10-21 (Claude Code; conservative interpretation of docs/08 "use authoritative region codes as primary keys", open to team review)

## D-013
**Decision:** The research pipeline is stdlib-only Python under `scripts/research/`, with an immutable raw store `data/raw/<SRC>/<SNAP>/` plus SHA-256 sidecars, and snapshot IDs of the form `SNAP-YYYY-MM-DD`.
**Reason:** Reproducible on any machine without installs; satisfies the raw/processed separation and caching rules in docs/04 and docs/16.
**Date:** 2026-10-21

## D-014
**Decision:** Simulation regions = 514 kabupaten/kota; province state is aggregated from them. BIG `TIPADM=6` unallocated island fragments (21 polygons) are rendered but are not simulation regions. "Wilayah terapung" secondary polygons belong to their parent kab/kota.
**Reason:** Matches the official Kemendagri/BPS count (416 + 98) and docs/07 per-region simulation; the fragments have no kab/kota code.
**Date:** 2026-10-21 (open to team review)

## D-015
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

## D-016
**Decision:** Seven presentation-only navigation groups, stored in `data/design/navigation_groups.json` and keyed by Kemendagri province codes: `sumatera`, `jawa`, `bali_nusa_tenggara`, `kalimantan`, `sulawesi`, `maluku`, `papua`. They are a map navigation taxonomy, not an administrative level, and not written into the official region registry. The display name "Sumatera" uses Indonesian spelling, consistent with the official province names and the full-Bahasa-Indonesia rule; the team's request wrote it as "Sumatra".
**Reason:** team-defined grouping (2026-10-21); docs/08 says island labels must not overwrite the official hierarchy.
**Date:** 2026-10-22

## D-017
**Decision:** BIG `LUASWH` is kept raw with its published label and declared unit "(HA)". It is annotated `UNIT_KM2_EVIDENCED` (legal/regulated area in km²) and never converted. `Shape_Area` is treated as planar square degrees and never used as an area. Polygon-derived area (`geom_area_km2`, WGS84 ellipsoidal equal-area) lives in a separate DERIVED column. Render layers carry no area fields.
**Reason:** three independent lines of evidence (`research/reports/AREA_UNIT_INVESTIGATION.md`). Which area figure the game shows is a later, explicit choice.
**Date:** 2026-10-22

## D-018
**Decision:** Kab. Sumbawa (OBJECTID 3424) is captured with `maxAllowableOffset=1e-7°` (maximum deviation about 1.1 cm) and stored under a distinct file name. BIG's server cannot return this feature at full resolution in any format (HTTP 500). The copy is reported as `recovered_features_not_full_resolution` and is not presented as untouched full-resolution data.
**Reason:** the alternatives were a missing region or a much coarser source; the deviation is about 2,000× below the 1:50.000 source accuracy.
**Date:** 2026-10-22

## D-019
**Decision:** Git stores the code, catalogs, cards, normalized and processed data, render LODs, and the raw sidecars (`.meta.json`) and access log. It does not store the 2.2 GB of full-resolution BIG polygon pages, which stay on disk as the immutable raw store and can be re-fetched and verified by SHA-256.
**Reason:** repository size. Provenance is preserved by the sidecars and `scripts/research/README.md`.
**Date:** 2026-10-22
