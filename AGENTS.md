# AGENTS.md

## Scope

This file defines team-wide rules for all agents and coding sessions operating inside the NUSANTARA repository.

## Prime directive

**Never silently invent. Never silently simplify. Never silently overwrite.**

## Human roles

- **Galih**: game director, technical integrator, primary programmer/reviewer, final decision maker for implementation.
- **Ananda**: character and visual design.
- **Cleo**: UI/visual/asset design.
- **Claude Code**: engineering and research automation assistant.
- **ChatGPT**: research lead, design strategist, systems/game-design reviewer, documentation assistant.

## General coding rules

- Read `CLAUDE.md` first.
- Use GDScript for Godot code unless a documented reason says otherwise.
- Keep gameplay logic independent from visual assets whenever possible.
- Treat Windows desktop as the primary UX/performance target; do not add mobile-first UI constraints.
- Prefer reusable systems over bespoke scripts.
- Treat data as first-class content.
- Preserve deterministic simulation inputs for reproducibility.
- Avoid frame-based `_process()` work for authoritative simulation unless justified.
- Do not create a scene/node per data entity just to represent simulation state.
- Simulation state and visual representation must remain separate.
- Never reduce semantic region coverage just to improve performance; optimize implementation, not correctness.

## Content rules

- Full game language: Bahasa Indonesia.
- Fictional president: Nara Adinata.
- Real-world Indonesian geography is intentional.
- Real-world cultural names and context are intentional.
- Historical cases are adapted from real events and clearly labeled as simulated when gameplay diverges from history.

## Data rules

Every factual record needs provenance metadata.

Minimum provenance fields:

- source institution
- title
- URL
- publication/update date
- retrieval timestamp
- geographic resolution
- reference year/period
- unit
- source status

## Do not

- fabricate data
- infer unsupported official statistics
- change units without recording conversion
- mix province-level data into district-level fields without a resolution flag
- copy article text verbatim into game content
- use copyrighted characters/assets by imitation
- treat AI-generated claims as sources
- use cultural stereotypes as mechanics

## Deliverable discipline

Keep raw data immutable. Derived datasets must be reproducible from raw data plus transformation code/configuration.
