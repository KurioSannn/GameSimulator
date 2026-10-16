# 10 TECHNICAL ARCHITECTURE PRINCIPLES

## Architecture ownership

Claude Code is responsible for proposing and implementing the concrete Godot architecture based on the product requirements, the actual repository, and current stable Godot best practices. The human team does not need to pre-select every class name, node hierarchy, serialization format, or subsystem implementation detail.

Before committing to an architecture, Claude Code must inspect the repository and, where available, consult the installed Godot version's official documentation. Prefer the smallest architecture that can satisfy the requirements without sacrificing maintainability.

## Core principles

### 1. Simulation is authoritative

The simulation layer owns the truth for dynamic game state.

UI reads from simulation state. UI must not become the source of truth.

### 2. Data-driven content

Policies, events, regions, cultural references, advisor content, and similar repeated content should be represented as data, not duplicated code.

### 3. Reusable controllers and services

Prefer reusable systems for:

- simulation orchestration
- event/case evaluation
- policy application
- resource/accounting systems
- sentiment
- save/load
- content registry
- map selection/navigation
- data provenance
- logging/telemetry for development

Exact decomposition is Claude Code's decision.

### 4. Resource-oriented content

Godot `.tres` is encouraged for reusable structured content when it fits. Use Resources for data/configuration; do not use `.tres` as a replacement for GDScript logic.

### 5. Separation of concerns

Keep distinct:

- raw research data
- normalized/master data
- game-ready data
- simulation state
- application flow
- rendering
- UI
- audio
- persistence

### 6. Full-region simulation semantics

All modeled regions must update every tick semantically, including off-screen regions. Optimizations may change *how* computation is performed but must not change geographic coverage or authoritative outcomes.

### 7. Desktop-first UX and input

The game is primarily a **Windows desktop `.exe` experience**.

Primary interaction:

- mouse click/drag
- mouse wheel zoom
- hover/tooltips
- keyboard shortcuts where beneficial

Design for desktop window sizes and readable information density first. Do not impose touch-target inflation, touch navigation patterns, or mobile-first responsive constraints on the core UI.

Android adaptation, if required for competition submission, should reuse the same simulation/application architecture and only introduce a thin platform/input adaptation layer.

### 8. Performance

Never attach a per-frame `_process()` loop to each region simply to simulate time. Avoid excessive Node counts and scene instantiation. The authoritative simulation should operate as a controlled batch/state update rather than a collection of hundreds of independent gameplay Nodes.

Avoid:

- one `_process()` per region
- one Node per database entity
- repeated parsing during gameplay
- network requests during play
- expensive allocations inside tight tick loops
- rebuilding all UI when only one state changed

### 9. Determinism

Where randomness affects simulation, support a controllable seed. A developer should be able to reproduce a reported outcome from a known save/data snapshot/simulation version/seed.

### 10. Testability

Core simulation logic must be testable without rendering the whole game. Prefer pure functions or isolated services for formulas and deterministic transformations.

### 11. Offline runtime

Gameplay must not depend on network connectivity, live APIs, cloud saves, or third-party servers. All runtime data is packaged locally.

### 12. Platform abstraction

Platform-specific behavior must be isolated. The core game should not contain desktop-vs-mobile conditionals throughout business logic.

### 13. Data versioning

Every data snapshot and game model must carry an explicit version. Saves must record the versions required to interpret them.

### 14. Best-practice technology selection

Claude Code must **choose the concrete technical stack within Godot using best practice**, rather than blindly following a prewritten stack beyond the agreed core constraints. It should evaluate:

- stable Godot version
- renderer appropriate to 2D desktop strategy gameplay
- scene architecture
- Resource usage
- signal/event approach
- serialization format
- input handling
- map rendering/hit testing
- automated testing strategy
- build/export configuration

If a non-default or third-party dependency is proposed, document why it is necessary, its license/compatibility, and the fallback if it becomes unavailable.

## Suggested high-level architecture

```text
Desktop Presentation
    ↓
Map / UI / Audio / Animation
    ↓
Application Flow
    ↓
Decision / Case / Save / Input Controllers
    ↓
Simulation Domain
    ↓
Regional State + National State + Causal Systems
    ↓
Game Data Snapshot / Resources
    ↓
Research Master Data
```

Exact implementation remains Claude Code's responsibility.
