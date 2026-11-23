# Execution report: narrative redesign, campaign, endings and case library (2026-11-23)

Executed by Claude Code on the user's redesign brief ("complete game redesign, narrative system, production-ready gameplay, and 50+ playable story cases"). Authoritative design: `docs/02_GDD.md`.

## What was attempted

1. Turn the decision sequence into a narrative game: prologue, cast, tutorial, story scenes for every case and choice, callbacks, quarterly transitions, journal, goals, endings.
2. Replace the silent priority scheduler with a visible agenda.
3. Calibrate endings from actual playthroughs instead of invented thresholds.
4. Remove U+2014 from player-facing text and prevent regressions.
5. Reach 50 researched, playable top-level cases.

## What succeeded

| Area | Result | Evidence |
|---|---|---|
| Story engine | `Narrative`, `Campaign`, `EndingEvaluator` (pure, headless-testable); `StoryPlayer` with typewriter, history, auto, skip, branching options; procedural backdrops; portraits | `game/src/story/*`, `test_story.gd` |
| Save | schema v6 with story state; v5 saves migrate without replaying the prologue | `test_story_state_survives_save_and_load`, `test_old_saves_skip_the_prologue` |
| First-time flow | menu -> prologue (with a remembered first choice) -> 7-step contextual tutorial -> agenda -> opening -> decision -> reaction -> quarter -> report | screenshots in this session; `prologue.json`, `tutorial.json` |
| Scheduling | agenda of up to 3, deterministic queue, explicit expiry with logged consequences, never-opened cases reported | `test_agenda_opens_visibly...`, `test_unattended_items_expire...`, `test_full_campaign...accounts_for_every_case` |
| Endings | 5 archetypes, calibrated thresholds, reflections that remember the prologue choice, summary screen with promises and decisions | `calibrate_endings.gd`, `endings.json` |
| Episodes | 32 major cases + 19 follow-ups have full episodes; every speaker and background validated | `test_every_case_has_a_complete_episode` |
| Library | Kumpulan Kisah: every top-level case playable in an isolated sandbox, never saved | `Game.start_scenario` |
| Language | 264 U+2014 rewritten in game text and authored docs; test guard | `scripts/text/em_dash.py`, `test_no_em_dash_in_any_game_text_or_code` |
| Cases | 18 new researched cases (CASE-0021..0038) | `scripts/story/author_cases.py`, `research/cases/CASE_REGISTRY.md` |

Tests: 177/177 headless; `scripts/validate_all.py` OK.

## Calibration finding (important)

Before rebalancing, a strategy that takes up **no** agenda item ("neglect") scored like governing (trust better than the median strategy, best fiscal). Unattended crises now cost trust (−3 in focus regions / −1.2 nationally) and six months of welfare/services loss. After rebalancing, neglect is at or near the bottom on welfare, trust and services and best only on fiscal health, a real trade-off.

Every strategy ends with welfare and trust below the starting level, because the historical shocks land regardless. Endings are therefore relative (top/bottom quartile of 47 plausible strategies). Distribution: Bertahan 27, Menguat 9, Janji 8, Krisis 4 (incl. neglect), **Warisan Besar 0** (aspirational; needs all four pillars in the top quartile plus kept promises). Recalibrate after adding cases or changing coefficients.

## Case research

- 18 new cases, all sourced from official pages fetched and read on 2026-11-23 (BNPB, Setkab, Kemenkes, BKPK, Kementan, Kemnaker, Kementerian PUPR, ESDM/Badan Geologi). Numbers are copied exactly; conflicting figures across releases are recorded in `rejected_or_unverified`.
- Dated-page traps caught and excluded: a BNPB Kalsel flood article from Dec 2025 and a Semeru relocation article from Nov 2025 (different events from the 2021 cases).
- Attempted and dropped: **PDNS ransomware 2024** (BSSN 404, Komdigi 403, kominfo.go.id DNS failure; no readable official source), **rice prices 2023** (official BPS/Setkab pages not found), **Cyclone Seroja presidential visit** claims (not verified; not used).
- Province-level data (stunting) is applied at province scope; no province values copied into district fields.

## Coverage

- **Playable top-level cases: 32 of the 50 target** (14 earlier + 18 new). Every one has a research record, 3 distinct choices, a full episode, working effects, schema validation and a standalone scenario.
- Island groups: all seven. Domains: floods, earthquakes, tsunami, volcanic eruptions and lahar, cyclone, drought, fire (peat, depot, landfill), health (outbreaks, stunting, TB, drug safety, remote care), energy, fisheries, mining, food and fertilizer, labour, air pollution, waste, fiscal policy.

## Known gaps

1. **18 more cases** are needed to reach 50. The pipeline (`author_cases.py` + `build_registry.py` + tests) is ready; each case needs real source verification, which is the slow part and was not shortcut.
2. Adviser and local portraits are generated placeholders (`art_pending`), pending the art team.
3. Regional mini-episodes that do not consume the quarterly slot are designed (GDD §13) but not implemented; follow-ups and callbacks currently carry the between-decision storytelling.
4. Scene position inside a dialogue is not saved (a reopened game replays the current scene from its start).
5. Warisan Besar was reached by none of the automated strategies; it may need tuning once more cases exist.
6. Windows hardware testing of trackpad gestures is still outstanding (from the controls report).

## Next actions

1. Research batches D to F (6 cases each) to reach 50, prioritising candidate topics with accessible official sources: rice and food prices, mangroves/coastal erosion, teacher distribution, inter-island freight, school rebuilding, coral reefs, regional procurement delays.
2. Recalibrate endings after the library reaches 50.
3. Art pass for the cast.
