# 26 DESKTOP-FIRST TECH STACK POLICY

## Purpose

Define what is fixed and what Claude Code must decide using current Godot best practices.

## Fixed constraints

- Engine family: Godot
- Primary scripting language: GDScript
- Primary runtime target: Windows desktop `.exe`
- Game language: Bahasa Indonesia
- Rendering style: 2D
- Runtime: offline
- All modeled regions simulated every internal tick
- Data-driven content
- Real Indonesian data/cultural provenance
- Multiple saves + autosave + quicksave

## Not fixed prematurely

Claude Code must decide, based on the actual Godot version and project state:

- exact Godot version
- renderer configuration
- scene tree decomposition
- autoload usage
- Resource classes
- whether a model-view-controller-like separation, ECS-inspired data loops, service-oriented approach, or another pattern is the best fit
- map rendering technique
- polygon hit-testing technique
- serialization format for research/game data
- save serialization format
- test framework or test conventions
- build automation

Do not introduce architecture buzzwords unless they solve an actual problem.

## Desktop-first design consequences

The primary UX assumes:

- mouse precision
- keyboard shortcuts
- hover information
- large information panels
- simultaneous map + dashboard visibility
- 16:9 landscape screen
- desktop-class CPU/memory budget

The UI must not be rebuilt around touch interactions.

## Performance strategy

Because all regions are semantically simulated every tick, simulation state should be held in efficient data structures rather than represented by hundreds of active gameplay Nodes. The map renderer should consume simulation state but remain decoupled from it.

The performance goal is **correct full-region simulation with predictable tick cost**, not artificial optimization that skips regions.

## Platform strategy

### Stage 1
Windows desktop development and QA.

### Stage 2
Windows release candidate.

### Stage 3
Only if competition rules still require it: Android export/adaptation without changing the authoritative simulation semantics.

## Decision protocol

When choosing a technical approach, Claude Code must document:

1. Problem
2. Options considered
3. Chosen approach
4. Why it is appropriate for this project
5. Rejected alternatives
6. Risks
7. How it will be tested

Store material decisions in `DECISIONS.md`.
