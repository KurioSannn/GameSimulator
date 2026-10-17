# SIMULATION IMPLEMENTATION PROMPT

After research contracts are stable, implement the NUSANTARA simulation in Godot.

## Non-negotiables

- all regions simulated every monthly tick
- simulation is authoritative
- UI is presentation only
- data-driven content
- offline
- testable
- deterministic seed/debug support
- scalable to full region count

## Start with a vertical slice

Implement first:

- current date/time
- a small but structurally representative set of regions
- region state
- national aggregation
- one resource flow
- one policy
- one historical case
- one sentiment computation
- one cascading consequence
- save/load

Then scale to all regions and full data.

## Do not

- hardcode policy behavior across many scripts
- create one process callback per region
- parse source files at runtime
- use network requests in gameplay
- store authoritative state only in UI nodes

Document the final architecture in `docs/TECHNICAL_DESIGN_FINAL.md`.
