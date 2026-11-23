# Execution report: final game experience milestone (2026-11-23)

Executed by Claude Code on the user's brief "NUSANTARA final game experience milestone" plus the follow-up request to replace procedural story visuals ("jangan pake svg gitu jelek kata designer ku") with generated or open-source art fitted to each context. Case count frozen at 50; no new research, geography or simulation systems.

## What was attempted and what succeeded

| Phase | Result | Evidence |
|---|---|---|
| C. Art | 29 painted 16:9 story backdrops replace the procedural scenes. Bayu, Yosef and Sekar get portraits with 4 expressions. All 100 episode locals get their own portrait, in the style of the team's Nara art. Nara and Laras keep the approved art. | `game/assets/story/`, `ART_MANIFEST.json` (141 files, SHA-256), AI usage log, `test_every_speaker_has_drawn_art_and_every_scene_a_painted_backdrop` |
| A. Balance | Agenda outcome categories (D-093). The D-092 raw-count rule is replaced by missed critical crises plus idle lapses. Recalibrated thresholds. A deterministic strong route reaches Warisan Besar (D-095). | `campaign.gd`, `endings.json`, `game/tests/data/strong_route.json`, `test_strong_route_reaches_warisan_besar_and_misses_no_crisis`, `test_active_prioritisation_is_not_neglect` |
| B. Save | Exact dialogue position is saved and restored (D-094). Simpan (F5) works inside dialogue. A finished term resumes into its ending. | `story_player.gd` `state()`, `main.gd` `_resume_story`, QA run below, `test_dialogue_position_survives_save_and_load` |
| D. Story | Content-level coverage checks for all 50 cases. Three reactions lacked a local voice and were fixed. Result 50/50, gated in `validate_all`. | `scripts/story/coverage.py`, `research/reports/STORY_COVERAGE.json` |
| E. Endgame | Personal legacy sequence built from state, the ending title revealed in-scene, an expanded Rapor Warisan, and Kumpulan Kisah thumbnails. | `ending_story.gd`, `test_legacy_sequence_is_built_from_the_term` |

## Ending balance (why there were zero Warisan endings)

- **Pillar.** Fiscal health was the binding constraint. Strategies that protect welfare, trust and services spend fiscal space to zero (fiscal p25 is 0.0). Ending with fiscal ≥ 8.4 while being top-quartile elsewhere needs choices that pay off later. Single-rule strategies (always a, always cheapest, random) cannot plan for that.
- **Not mathematically blocked.** The thresholds were consistent with their own distribution. The 47 automated strategies were not representative of competent play: none looked ahead, prioritised critical crises, or delegated deliberately.
- **Strong route.** A 4-quarter lookahead per decision, critical crises answered before their window closes, and non-critical items about to lapse delegated on purpose. Result: welfare −3.72, trust −6.87, services +1.64, fiscal 13.2, promises 3 of 4 kept, 0 missed critical crises, Warisan Besar. Thresholds were not lowered: they remain the p75/p25 of the 47 plausible strategies.
- **Distribution over 49 runs.** Warisan 1, Menguat 1, Bertahan 28, Janji 9, Krisis 10 (incl. neglect).
- **Neglect vs prioritisation.** In real play one item must be taken each quarter, so active players have 0 idle lapses. Their worst negligence score is 4, against 19 for the neglect counterfactual. The line is 8.

## Mid-dialogue save QA (real game run)

1. `--story=opening:CASE-0055 --beats=4 --qa-save` printed `resume=drain index=4 speaker=bayu`.
2. A fresh process with `--qa-load` printed `index=4 speaker=bayu`, the same backdrop and the same line, restarting its typewriter reveal.

## Tests

- 183/183 headless tests pass.
- `validate_all` OK, including story coverage 50/50.
- Em dash check: no occurrences in scope. Out-of-scope generated files are listed by the tool and unchanged.

## Known gaps

1. The generated art is pending review by the team's artists. The manifest and the Figma draft file allow replacement one file at a time.
2. Expression variants exist for the three advisers only. Nara, Laras and the locals use one portrait each, plus subtle motion.
3. The strong route is a calibration artefact. Regenerate it after content or coefficient changes (`CAL_ONLY=strong` speeds this up).
4. Windows trackpad hardware testing is still outstanding (earlier report).

## Next action

The art team reviews the portraits and backdrops. The team plays the strong route by hand to confirm it feels like good governance rather than an exploit.
