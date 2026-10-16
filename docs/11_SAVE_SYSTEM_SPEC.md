# 11 SAVE SYSTEM SPECIFICATION

## Goal

Provide safe, flexible, offline saving at any point in gameplay.

## Requirements

- offline
- save anytime
- multiple manual save slots
- no arbitrary low fixed slot cap
- autosave
- quicksave
- resume after restart
- metadata preview
- data/model versioning
- safe handling of corrupted save data
- migration strategy where practical

## Save metadata

At minimum:

- save_id
- save_label
- created_at
- updated_at
- game_year
- quarter
- month/tick
- player identity
- current national indicators
- current budget
- current location/UI context if useful
- game data snapshot ID
- simulation version

## Save/load integrity

Loading a save must restore:

- all national dynamic state
- all regional dynamic state
- event states
- delayed effects
- active policies
- historical memory
- sentiment
- RNG state/seed strategy where required

## Save semantics

A save may be created at any moment the gameplay state is stable.

Do not save halfway through a non-atomic state mutation.

## Corruption handling

If a save is invalid:

1. do not crash
2. present a clear message
3. preserve other save slots
4. keep autosave recovery if available

## Save-scumming

The game does not need to punish save/load. Experimentation is part of the simulation experience.
