# Execution report: pointer/trackpad controls and case re-verification (2026-11-23)

Executed by Claude Code at the user's request ("make it comfortable with a touchpad or mouse; continue the cases and research as many as possible").

## 1. Map controls

### What was attempted
The user reported that the map could only be moved with click-and-hold. Cause: the default 3D camera (`MapCamera3D`) handled the mouse wheel and right-drag, but ignored `InputEventPanGesture` (two-finger trackpad swipe) and `InputEventMagnifyGesture` (pinch). On macOS a trackpad swipe arrives only as a pan gesture, so it did nothing. The +/− buttons were hidden inside the collapsed "PETA ▾" card.

### What succeeded
- New `game/src/map/map_nav_input.gd` (`MapNavInput`) translates every pointing device into two intents (`pan(view_delta_px)`, `zoom(zoom_in, at)`). Both cameras use it (`nav_pan`, `nav_zoom`).

  | Input | Action |
  |---|---|
  | Two-finger trackpad swipe | Pans the map, with OS momentum |
  | Trackpad pinch, Ctrl/⌘ + scroll | Zooms toward the fingers/cursor |
  | Mouse wheel | Zooms toward the cursor; fractional notches from high-resolution wheels and touchpads give fractional zoom |
  | Shift + wheel, horizontal wheel | Pans sideways |
  | Touchscreen, two fingers | Pinch zooms and drag pans; one finger keeps the emulated left-drag/click |
  | Left-drag, right-drag, WASD/arrows, Q/E/R/F, Home | Unchanged |

- New setting **Pengaturan › Kontrol › GULIR / TRACKPAD** (`scroll_mode`): Otomatis / Gulir = zoom / Gulir = geser peta. The last option exists for Windows precision touchpads, which deliver wheel events instead of pan gestures.
- Always-visible **+ / − / ⌂** buttons under the left navigation column (`Hud` › `ZoomHUD`).
- The HUD zoom buttons in 3D now go through the clamped, cursor-anchored zoom. Before, they set the distance directly and skipped the safe-zone clamp.
- During a two-finger touch gesture, Main no longer treats the emulated left drag as a pan or click.
- Tests: `game/tests/test_map_input.gd`, 7 tests.

### Known gaps
- Windows precision-touchpad behaviour was not tested on hardware (development machine: macOS). The mapping follows Godot's documented event types.
- Pan speed constants (`PAN_GESTURE_PX`, `WHEEL_PAN_PX`) are tuned by reasoning, not user testing.

## 2. Cases

### Finding: the 2026-11-03 records for CASE-0009…0020 were not trustworthy
- Only CASE-0001…0008 were present in `game/data/cases`; CASE-0009…0020 existed only as research records.
- `CASE_REGISTRY.md` listed different topics for 0009…0020 than the files contained. For example, the registry said CASE-0015 was Jabodetabek air pollution; the file was about cantrang.
- URL audit of all 50 cited sources (`2026-11-23_case_source_url_audit.json`): 17 returned 404, 1 returned 401, 10 returned 403, 15 were unreachable (DNS/TLS/timeout), and 7 returned 200. One of those 200s was a soft-404 page: BPS for CASE-0009 shows "404 - Page Not Found". Most slugs follow invented patterns such as `bnpb.go.id/laporan-erupsi-merapi-2010`. Under the CLAUDE.md rule "never fabricate source URLs", none of these records can feed game content.

### What was done
- **Re-researched six topics** with sources that were fetched and read on 2026-11-23. Each research record was rewritten and a playable game case created:

  | Case | Topic | Sources (all read 2026-11-23) |
  |---|---|---|
  | CASE-0011 | Pemadaman listrik Jawa-Bali, 4 Aug 2019 | Setkab 2019-08-05; Ombudsman clipping of its 14 Nov 2019 investigation (classed as news) |
  | CASE-0013 | KLB campak & gizi buruk Asmat, 2018 | Kemenkes 2018-01-14, 2018-02-05 |
  | CASE-0014 | Tsunami Selat Sunda, 22 Dec 2018 | Setkab/BNPB 2018-12-25; ESDM/Badan Geologi 2018-12-24 |
  | CASE-0015 | Larangan cantrang, Jan–May 2018 | Setkab 2018-01-16; Setneg 2018-01-18, 2018-05-08 |
  | CASE-0016 | Banjir bandang Sentani, Mar 2019 | Setkab/BNPB 2019-03-17, 2019-03-19 |
  | CASE-0020 | GGAPA pada anak, 2022 | Kemenkes 2022-10-19, 2022-11-01, 2022-11-16 |

  Claims that could not be verified were moved to `rejected_or_unverified`. Examples: total affected PLN customers, the cantrang regulation number, Cycloop/BMKG causal claims, and EG/DEG details.
- **Quarantined** CASE-0009, 0010, 0012, 0017, 0018 and 0019: status set back to `candidate` (the schema's vocabulary), with the failed URL audit recorded in `status_note`, and `game_adaptation_ref: null`. `scripts/validate_all.py` passes. Their content is kept for reference only.
- Access log: 14 successful retrievals and 50 audit rows (failures included) appended to `research/sources/access_log.jsonl`.
- The registry was rewritten to match the files.

### Scheduling constraint discovered
The game presents one decision per quarter, which gives 20 slots per term. With 14 major cases plus follow-ups, demand is about 21 slots. With the new cases at the same `story_priority` (10), one major case was crowded out per playthrough, including CASE-0004, the local-wisdom case. The new cases now use `story_priority: 8`, so the original eight always keep their slot. Measured over 6 full-term playthroughs (seeds 13 and 7 × choices a/b/c), the original eight always appeared and 2–3 of the six new cases were skipped per run.

**Decision needed from the team:** keep this variety-per-playthrough behaviour, or allow more than one decision per quarter? That changes the core loop and is not decided by Claude.

### Coverage
- Playable major cases: 8 → 14.
- Island groups: all seven.
- New domains: grid reliability, non-tectonic tsunami warning, fisheries, child drug safety, and remote child health.

### Tests
Headless suite: 167/167 pass. The 7 new input tests are included, and the generic case-template tests cover all six new cases: fact/fiction labels, ≥3 mechanically distinct choices, divergent end states over a term, and the decision gate.

### Skipped / failed
- Rice 2023 (CASE-0009 topic): the official BPS and Setkab pages were not found in this session; only news reports were. Not shipped.
- The BNPB "Info Bencana Desember 2018" PDF was downloaded but not parsed.
- The DPR blackout brief returned 403.
- No in-window screenshot of a new case modal was taken. The screenshot automation answers only the first pending case, so it cannot reach them.

### Next actions
1. Team decision on decisions-per-quarter capacity.
2. Re-research the quarantined topics: rice 2023 via the BPS inflation release, Merapi 2010, Rempang 2023, IKN, Kinipan, Citarum.
3. Player test of trackpad speeds on Windows and macOS hardware.
