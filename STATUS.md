# STATUS

## Current phase

Research bootstrap: **geography baseline milestone closed** (2026-10-22, snapshot `SNAP-2026-10-21`).

## Locked

- real Indonesia setting
- fictional protagonist Nara Adinata
- full Bahasa Indonesia
- real/latest official baseline data
- full per-region simulation every monthly tick
- 5-year / 20-quarter baseline with 60 monthly ticks
- story-driven sandbox
- 100+ real-world case library target
- regional sentiment
- cascading consequences
- local wisdom as researched governance mechanics
- offline
- save anytime + multiple saves + autosave + quicksave
- Godot 2D + GDScript
- Figma + SVG visual pipeline
- Claude Code engineering role
- full competition target: APK + EXE

## Done

- **Research pipeline** (`scripts/research/`): cached raw capture with SHA-256 sidecars, retry/backoff and access log. Stdlib Python plus project-local mapshaper 0.7.79 (`tools/geo/`).
- **Source registry:** `data/catalog/source_registry.csv` and cards in `research/sources/` (SRC-0001 to SRC-0008).
- **Region registry:** 38 provinsi and 514 kab/kota (416 + 98), keyed by Kemendagri code, with the BPS crosswalk and a 1:1 BIG polygon mapping (`data/normalized/geography/`).
- **Raw BIG geometry:** complete, 541/541 features, 2.22 GB, every file verified. Kab. Sumbawa is a declared 1e-7° recovery copy (D-018).
- **Render LODs** (Douglas–Peucker 1,000 / 100 / 40 m; 5.4 / 15.2 / 28.3 MB). Each has 514 kab/kota, 38 provinces and 21 fragments, and passes 15/15 hard checks: IDs, codes and parents preserved; no crossings; no containment overlaps; adjacency 997/997; island survival (D-015, DATA-0003).
- **Island audit:** 0 parts lost and 0 noticeable parts displaced at any LOD. Small islands are drawn shrunken (documented).
- **Province outlines:** dissolved from kab/kota. Against BIG's inter-province lines they agree to a median of 7.5 m, with 99.75 % within 50 m.
- **Navigation groups:** seven presentation-only groups covering every province exactly once (D-016).
- **Area-unit investigation:** `LUASWH` is km² legal area despite its "(HA)" label. It is kept raw, with the evidenced unit stored as separate metadata (D-017).
- **Tests:** 44/44 pass, 0 skipped (`python3 -m unittest discover -s scripts/research/tests`).
- **Reports:** `research/reports/GEOMETRY_VALIDATION_REPORT.md`, `AREA_UNIT_INVESTIGATION.md`, `RESEARCH_BOOTSTRAP_REPORT.md`. Technical documentation: `docs/28_GEOGRAPHY_DATA_PIPELINE.md`.

## Not yet built

- Godot import of the LODs (local/projected coordinates for float32, packed format, in-engine load timing)
- domain ingestion (demography, economy, fiscal, ...): BPS WebAPI key needed
- final title
- final Nara biography beyond baseline
- complete cultural knowledge base
- 100+ validated cases
- final causal coefficients
- final simulation architecture, UI, assets

## Next action

1. **Team:** register a BPS WebAPI key (GAP-0009); obtain the Kepmendagri 300.2.2-2138/2025 PDF, for example via JDIH id=1937 from another network (GAP-0001); confirm the BIG reuse terms.
2. **P0 domain ingestion** (population, PDRB, poverty, IPM, APBD) joined through the BPS↔Kemendagri crosswalk.
3. **Godot map import prototype** using the LODs.

## Open issues carried forward

- GAP-0003: decree-number conflict (2138 / 2340 / 2430). Bibliographic only.
- GAP-0010: Sumbawa full-resolution geometry is not served by BIG.
- GAP-0011: no BPS area table for 7 provinces.
- GAP-0012: BPS Sulawesi Tenggara 2025 area values are about 1000× too large.

## Platform correction

The project is now explicitly **Windows desktop-first**. The core UX and performance work should target `.exe`. Android is secondary because the current IT-CAS guidebook states APK + EXE are required; do not let mobile-first design dictate the architecture.
