# DESKTOP-FIRST EXECUTION PROMPT

Use this prompt when asking Claude Code to begin or continue implementation.

You are the primary engineering agent for NUSANTARA. Build and validate the game as a **Windows desktop-first 2D strategy/governance simulation**. Do not make mobile-first UI assumptions.

## 1. Ground truth

Read:

- `CLAUDE.md`
- `AGENTS.md`
- `docs/00_PROJECT_CHARTER.md`
- `docs/01_PRD.md`
- `docs/02_GDD.md`
- `docs/03_COMPETITION_REQUIREMENTS.md`
- `docs/07_SIMULATION_SPEC.md`
- `docs/08_MAP_AND_GIS_SPEC.md`
- `docs/10_TECHNICAL_ARCHITECTURE_PRINCIPLES.md`
- `docs/11_SAVE_SYSTEM_SPEC.md`
- `docs/22_UI_UX_SPEC.md`
- `docs/26_DESKTOP_FIRST_TECH_STACK_POLICY.md`
- `STATUS.md`
- `DECISIONS.md`

Read the competition guidebook whenever a rule needs verification.

## 2. Platform priority

Primary target: **Windows desktop `.exe`**.

Design, implement, test, benchmark, and polish desktop first.

The competition guidebook states that APK + EXE are required. Therefore do not delete the Android export path from the project documentation. Instead, treat Android as a **secondary compliance pass after desktop stability** unless the organizers clarify the requirement.

## 3. Choose best-practice implementation

Do not ask the human to predefine every Godot architecture choice. Inspect the repository and choose the best-practice implementation that fits the requirements. Keep it simple, modular, testable, data-driven, and performant.

Use GDScript unless there is a compelling documented reason not to.

Use `.tres`/Godot Resources for reusable data/content when appropriate; keep executable behavior in `.gd`.

## 4. Desktop UX contract

Build for 16:9 desktop screens first.

Primary input:

- mouse
- keyboard
- hover
- wheel zoom
- drag pan

Do not add mobile-first touch constraints.

The main gameplay surface should feel like a desktop strategy game: map + information panel + state dashboard + case/decision interface.

## 5. Simulation contract

All modeled regions must be simulated individually every monthly tick. No off-screen skipping. No lazy simulation based on UI visibility.

You may batch computations, use arrays/dictionaries/structs/resources, precompute coefficients, or use other efficient techniques as long as semantic coverage and deterministic reproducibility are preserved.

Avoid one active Node/process loop per region.

## 6. Data contract

Data layer stores actual source values and units. UI abbreviates only for presentation.

Never overwrite raw data.

Every dataset and field must retain provenance where applicable.

Never fabricate missing values.

## 7. Development order

Prefer:

```text
repository audit
→ architecture decision
→ minimal vertical slice
→ simulation core
→ region registry/map
→ data ingestion
→ case engine
→ sentiment/causal model
→ save system
→ UI polish
→ content scale-up
→ performance hardening
→ Windows release candidate
→ Android compliance pass if still required
```

Do not spend weeks building art or 100 cases before the first playable vertical slice validates the core loop.

## 8. Vertical slice requirement

Build one fully working vertical slice with:

- Indonesia map subset or test geography
- one clickable region
- one regional state
- one national state
- one real-data baseline record
- one case inspired by a real event
- three decisions
- one delayed consequence
- sentiment change
- save/load
- desktop UI

Only after this slice works should the team scale the data/content volume.

## 9. Reporting

At the end of each execution phase update:

- `STATUS.md`
- `DECISIONS.md` when needed
- a dated execution report under `research/reports/`

Report actual results, not aspirational completion.
