# 02 GAME DESIGN DOCUMENT (authoritative)

_Status: authoritative as of 2026-11-23. Supersedes the earlier "GDD baseline" in this file; reconciles docs/20 (story & case engine), docs/21 (character bible) and docs/22 (UI/UX). Where an older document disagrees with this one about narrative, campaign or endings, this document wins. Simulation semantics remain defined by docs/07 and docs/31._

## 1. Identity

| | |
|---|---|
| Title | **NUSANTARA** |
| Subtitle | **LIMA TAHUN MENJAGA NEGERI** |
| Promise | Satu negeri. Ratusan cerita. Setiap keputusan meninggalkan jejak. |
| Genre | Narrative governance simulation, management adventure, story-driven strategy |
| Platform | Windows desktop first (mouse, keyboard, trackpad); offline |
| Language | Bahasa Indonesia throughout |

The player is **President Nara Adinata** (fictional; docs/21) at the start of a five-year term in **real Indonesia** (38 provinces, 514 kabupaten/kota, each simulated every month). The emotional fantasy: *"I am responsible for a country. I cannot solve everything immediately, but my decisions can make people's lives better or worse."*

## 2. Objective: Tujuan Masa Bakti

Four pillars, always visible on the HUD and explained in the prologue. Each maps to existing authoritative variables; nothing new is invented.

| Pillar | Variable (national, population-weighted when available) |
|---|---|
| Kesejahteraan Warga | mean `welfare` |
| Kepercayaan Publik | mean `trust` |
| Pelayanan Publik | mean `services` |
| Kesehatan Fiskal | `fiscal_space` level |

Pillars are shown as plain trend words (membaik / stabil / menurun) since the start of the term. Detailed numbers are one click away (Tujuan Masa Bakti screen).

**Honest framing (calibration finding).** The term contains many real crises whose shocks land regardless of policy; in every tested strategy welfare and trust end below their starting level. The game therefore judges *how well the damage was contained relative to plausible play and to neglect*, and says so on the Goals screen.

## 3. Core loop

```
Quarter start
  -> Agenda Kuartal (up to 3 open issues, each with time left and what happens if postponed)
  -> Player takes ONE issue (the quarter's major decision)
  -> Opening scene (story) -> Decision panel (who benefits, who bears the cost, now vs later)
  -> Choice-specific reaction scene
  -> Optional: explore map/regions, policies, budget
  -> LANJUTKAN KUARTAL (3 monthly ticks for all 514 regions)
  -> Quarter transition scene (lines chosen from actual pillar changes)
  -> Callback scenes (characters remember earlier choices; text picked by real state)
  -> Unattended issues resolve with explicit consequences
  -> Next agenda
```

20 quarters = 60 monthly ticks. One major decision per quarter.

## 4. Campaign scheduling (replaces silent priority picks)

- Every case whose trigger conditions hold is **opened** on the agenda, up to 3 at a time; further eligible cases wait in a visible queue in deterministic order (story priority, trigger month, id).
- An agenda item can wait its window (default 3 quarters, follow-ups 2). When the window ends it is **handled without the President**: its shock applies plus unattended costs (base: trust −3 in focus regions or −1.2 nationally, welfare and services −0.4/month for 6 months), scaled by **outcome category** (D-093):

| Category | Meaning | Cost share (trust / losses) |
|---|---|---|
| Ditangani | the President decided it | none |
| Diserahkan ke kementerian | handed over on purpose (non-critical only; does not use the quarter's decision) | 35% / 50% |
| Teratasi lewat keputusan lain | lapsed, but a decision in the same province covered it | 30% / 30% |
| Tergeser krisis lain | lapsed while the President took up critical issues | 50% / 75% |
| Terlewat tanpa tindakan | lapsed in a quarter where nothing was taken up | 100% |
| Krisis besar yang terlewat | a critical crisis lapsed while lesser items were taken | 100% |

  Critical = trigger damage ≥ 8 or an episode flagged critical (deadly outbreaks). The agenda marks them KRISIS BESAR. Everything is logged, written to Buku Kisah with its category, and narrated.
- Cases that never open during a term are listed at the end and remain playable in Kumpulan Kisah. **No case disappears silently.**
- Headless regression sessions keep the legacy one-case pick so earlier golden masters stay valid (`Campaign.enabled()` is false there).

## 5. Narrative system

Data-driven, no per-case scripts.

| Content | File |
|---|---|
| Cast | `game/data/story/cast.json` |
| Prologue | `game/data/story/prologue.json` |
| Tutorial | `game/data/story/tutorial.json` |
| Quarter transitions | `game/data/story/quarters.json` |
| Endings | `game/data/story/endings.json` |
| Credits | `game/data/story/credits.json` |
| Case episodes | `game/data/story/episodes/<CASE-ID>.json` (merged into the case at load) |

**Beat format:** `{s: speaker, e: expression, t: text, bg: background, if: condition, set: {flag: value}, options: [...] , pick: [{if, beats}]}`.

**Conditions** = simulation conditions plus story keys: `flag`, `choice`, `delta` (change of focus-region means since the decision), `pillar` / `pillar_value` / `pillar_q`, `promise`, `agenda_open`, `promises_due`. Story text therefore always describes the actual simulated state.

**Episode structure (every case):** opening, per-choice info (intent, helps, burden, now, later), per-choice reaction, callbacks (after N quarters, with state-dependent variants), unattended scene, journal lines, optional promises.

**Promises:** delayed-benefit choices create a promise with a due date and a state check (e.g. flood protection up by 10 in the focus regions). Promises are kept or broken against real state and feed the ending.

**State:** `SimWorld.story` (save schema v6): flags, seen scenes, pending scene queue, decision snapshots, callbacks, promises, journal, met characters, pillar history per quarter, agenda, tutorial progress. v5 saves migrate with the prologue marked done.

## 6. Cast (fictional; docs/21 rules apply)

| Id | Name | Role | Voice |
|---|---|---|---|
| nara | Nara Adinata | Presiden | calm, concise, curious, occasionally over-analytical |
| laras | Laras Prameswari | Sekretaris Presiden | orderly, warm, always names the next step |
| bayu | Bayu Hartono | Penasihat Keuangan | careful, dry humour, "who pays and what waits" |
| yosef | Yosef Latumahina | Penasihat Pembangunan Daerah | field person, distances, boats, village names |
| sekar | Sekar Anindita | Penasihat Komunikasi Publik | quick, blunt, reads public mood |

Local characters are fictional composites per episode (e.g. Bu Yati in Jakarta Timur, Pak Asep in Lebak) and return in that case's follow-ups, callbacks and the legacy sequence. No line quotes or impersonates a real person.

**Art.** Nara and Laras use the team's approved art. Bayu, Yosef and Sekar have portraits with four expressions (netral, senyum, cemas, serius; moods map onto these families). All 100 episode locals have their own portrait (`game/assets/story/portraits/locals/<CASE>_<id>.jpg`). Story scenes use 29 painted 16:9 backdrops (`game/assets/story/backgrounds/<kind>.jpg`) with a slow drift (none with reduced motion). All new art was generated with Figma AI at the user's request in the style of the team's Nara art, is listed with checksums in `game/assets/story/ART_MANIFEST.json`, logged in the AI usage log, and pending the art team's review. A test fails if any speaker or scene falls back to a placeholder.

## 7. First-time experience

Main menu (Mulai Pemerintahan Baru, Lanjutkan, Muat Permainan, Kumpulan Kisah, Cara Bermain, Kredit, Pengaturan) -> prologue (palace morning, cabinet introductions, the four goals, a small first choice about which goal matters most, the 20-quarter structure) -> contextual tutorial, one action at a time: pan, zoom, select a region, open the agenda, decide, advance the quarter, read the result -> first agenda (CASE-0001 New Year floods) -> opening scene -> decision -> reaction -> quarter -> first report.

Tutorial and prologue choices are saved; continuing a save never replays the prologue. Tutorial can be replayed from Pengaturan or Buku Kisah.

## 8. Endings

Five archetypes: **Warisan Besar**, **Nusantara yang Menguat**, **Pemerintahan yang Bertahan**, **Janji yang Belum Selesai**, **Krisis Mandat**.

Each pillar is rated good / fair / poor against the p75 / p25 of **47 plausible deterministic full-term campaigns** (always a/b/c, cheapest, costliest, first/last agenda item, 40 seeded random strategies). Two reference runs sit outside the quartiles: a **neglect counterfactual** (never takes an item) and a **strong-governance route** (4-quarter lookahead per decision, critical crises answered before their window closes, deliberate delegation; `game/tests/data/strong_route.json`, replayed by the test suite). Crisis requires sustained failure (trust in the bottom decile for 4+ quarters with poor trust, 3+ poor pillars, or negligence: missed critical crises plus idle lapses ≥ 8). Warisan Besar needs all four pillars good, 60% of settled promises kept and no missed critical crisis; Nusantara yang Menguat allows at most one.

**Legacy sequence** (`EndingStory`, built from actual state): (1) the final presidential address, recalling the prologue priority, the defining decision and the promises; (2) a map overview of Indonesia naming the provinces that improved most and those still struggling, and any critical crisis missed; (3) returning local characters from the decisions that changed their regions most, speaking to how their place fared; (4) each adviser's verdict on the pillar they care about (Bayu fiscal, Sekar trust, Yosef services, Laras promises); (5) the ending title revealed in the scene, the archetype scene and the closing; (6) the Rapor Warisan screen (ratings, agenda outcome categories, provinces, promises, decisions) with new campaign and Kumpulan Kisah buttons.

Calibrated distribution (2026-11-23, 50 cases, 49 runs): Bertahan 28, Janji 9, Krisis 10 (incl. neglect), Menguat 1, **Warisan Besar 1 (the strong route)**. Warisan is demanding but attainable by excellent, plausible play. Warisan Besar is aspirational: it needs top-quartile results on all four pillars plus kept promises. **Recalibrate whenever cases or coefficients change.**

## 9. Case library

Top-level playable cases (`class: major_historical`) each have: a distinct real event and geography, a research record with sources read on the retrieval date, at least three mechanically distinct choices, a full narrative episode, working simulation effects, schema validation, and a standalone scenario. Follow-ups are narrative consequences, not counted as cases.

**Kumpulan Kisah** plays any top-level case in an isolated sandbox session (fast-forwarded to its month), never touches the campaign or its saves, and ends one year after the decision with a summary and a replay option.

Registry: `research/cases/CASE_REGISTRY.md`. Authoring source for cases from CASE-0021: `scripts/story/author_cases.py`.

## 10. Player-facing language rules

Natural Bahasa Indonesia conversation; one idea per beat; no news-article, journal or press-release style; no citations, URLs or provenance in normal play (sources remain in research records and appear in game only with the developer setting "Tampilkan sumber data"). No U+2014 em dash in any game text (`scripts/text/em_dash.py --check`, guarded by a test). Historical inspiration is stated once per case as "diangkat dari peristiwa nyata; pilihan dan akibatnya simulasi".

## 11. UX rules

One full-screen story interaction owns focus at a time; it swallows map and HUD input. Dialogue: typewriter (Lambat/Normal/Cepat/Langsung), auto-advance, history (H), skip (Esc), number keys for options. Map: left-drag or two-finger swipe pans, wheel/pinch/Ctrl+scroll zoom, right-drag orbits, +/−/⌂ always visible. Reduced motion is respected by backdrops and portraits. Layout verified at 1280×720 and 1600×900.

## 12. Save / load

World + story state in one save (schema v6). **The exact dialogue position is saved** (D-094): resolved beats including chosen option replies, beat index, speaker and expression, backdrop, reveal state, open options, recent history, and the flow it belongs to (prologue, case scene, quarter transition, ending). Loading resumes at that beat without re-applying any effect. Simpan (F5) works inside dialogue. A term that ended before its ending played resumes into the ending. Scenario mode is never saved. Autosave each quarter in campaign mode only.

## 13. Out of scope / later

Voice acting; expression variants for Nara, Laras and locals; human redraws of generated art if the art team prefers; regional mini-episodes that do not consume the quarterly slot; more case batches toward the 100+ library goal (docs/20).
