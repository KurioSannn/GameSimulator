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
| Episodes | 50 major cases + 19 follow-ups have full episodes; every speaker and background validated | `test_every_case_has_a_complete_episode` |
| Library | Kumpulan Kisah: every top-level case playable in an isolated sandbox, never saved | `Game.start_scenario` |
| Language | 264 U+2014 rewritten in game text and authored docs; test guard | `scripts/text/em_dash.py`, `test_no_em_dash_in_any_game_text_or_code` |
| Cases | 36 new researched cases (CASE-0021..0056); 50 playable top-level cases | `scripts/story/author_cases.py`, `research/cases/CASE_REGISTRY.md` |

Tests: 178/178 headless; `scripts/validate_all.py` OK.

## Calibration finding (important)

Before rebalancing, a strategy that takes up **no** agenda item ("neglect") scored like governing (trust better than the median strategy, best fiscal). Unattended crises now cost trust (−3 in focus regions / −1.2 nationally) and six months of welfare/services loss. After rebalancing, neglect is at or near the bottom on welfare, trust and services and best only on fiscal health, a real trade-off.

Every strategy ends with welfare and trust below the starting level, because the historical shocks land regardless. Endings are therefore relative (top/bottom quartile of 47 plausible strategies).

**Recalibration at 50 cases.** New thresholds: welfare good ≥ −3.97 / poor ≤ −5.12; trust −7.99 / −9.94; services −0.72 / −2.84; fiscal end 8.4 / 0.0; crisis trust −10.96. With the larger library, neglect (19 items expired, untouched fiscal) rated "Bertahan", so a rule was added (D-092): 15+ expired items is Krisis Mandat (the plausible-strategy maximum is 12). Distribution: Bertahan 20, Menguat 9, Janji 8, Krisis 11 (incl. neglect), **Warisan Besar 0** (aspirational). A median of 9 items expire even under active play: with one decision per quarter, prioritising is the game.

## Case research

- 36 new cases, all sourced from official pages fetched and read on 2026-11-23 (BNPB, Setkab, Kemenkes, BKPK, Kementan, Kemnaker, Kementerian PUPR, ESDM/Badan Geologi, KKP, KLHK and others). Numbers are copied exactly; conflicting figures across releases are recorded in `rejected_or_unverified`.
- Dated-page traps caught and excluded: a BNPB Kalsel flood article from Dec 2025 and a Semeru relocation article from Nov 2025 (different events from the 2021 cases).
- Attempted and dropped: **PDNS ransomware 2024** (BSSN 404, Komdigi 403, kominfo.go.id DNS failure; no readable official source), **rice prices 2023** (official BPS/Setkab pages not found), **Cyclone Seroja presidential visit** claims (not verified; not used), Central Java drought, Sumedang earthquake, Komodo tourism (kemenparekraf DNS), tol laut (hubla DNS), mangroves (BRGM certificate error), PPPK teachers (kemdikbud DNS), Kertasari and Garut earthquakes (too minor for a top-level case).
- Victims' names published in BNPB lists are never reproduced; officials are never quoted in dialogue; conflicting figures across releases (e.g. Inpres Jalan Daerah Rp14,6 T vs Rp14,7 T; specialist shortage 29.179 vs ~65 ribu on different bases) are recorded in `rejected_or_unverified`.
- Province-level data (stunting) is applied at province scope; no province values copied into district fields.

## Coverage

- **Playable top-level cases: 50 of the 50 target** (14 earlier + 36 new). Every one has a research record, 3 distinct choices, a full episode, working effects, schema validation and a standalone scenario.
- Island groups: all seven. Domains: floods, earthquakes, tsunami, volcanic eruptions and lahar, cyclone, drought, fire (peat, depot, landfill), health (outbreaks, stunting, TB, drug safety, remote care), energy, fisheries, mining, food and fertilizer, labour, air pollution, waste, fiscal policy.

## Known gaps

1. The 50-case target is met; the 100+ library goal (docs/20) remains. With 20 decision slots, most cases are seen via the agenda, expiry or Kumpulan Kisah rather than decided in one term; whether to allow more decisions per quarter is a team design decision.
2. Adviser and local portraits are generated placeholders (`art_pending`), pending the art team.
3. Regional mini-episodes that do not consume the quarterly slot are designed (GDD §13) but not implemented; follow-ups and callbacks currently carry the between-decision storytelling.
4. Scene position inside a dialogue is not saved (a reopened game replays the current scene from its start).
5. Warisan Besar was reached by none of the automated strategies; it may need tuning once more cases exist.
6. Windows hardware testing of trackpad gestures is still outstanding (from the controls report).

## Next actions

1. Further case batches toward 100, prioritising topics with readable official sources (food prices, coastal erosion, teacher distribution, inter-island freight, school rebuilding).
2. Tune Warisan Besar reachability with the team (still 0 of 47 strategies).
3. Art pass for the cast.
