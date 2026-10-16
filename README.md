# NUSANTARA

## AI-Assisted Game Development Project

**Working title:** NUSANTARA: THE MANDATE  
**Codename:** NUSANTARA  
**Engine:** Godot 2D  
**Language:** GDScript  
**Primary development assistant:** Claude Code  
**Visual workflow:** Figma + SVG + GPT-assisted generation  
**Audio:** Lyria family / approved music-generation workflow  
**Voice:** AI TTS workflow, tool to be finalized

## Executive concept

NUSANTARA is a data-driven 2D governance simulation set in **real Indonesia**. The player controls a **fictional president, Nara Adinata**, and leads Indonesia through a five-year administration. The geographic world, administrative regions, public datasets, cultural context, local wisdom, and historical problem cases are grounded in real Indonesian sources. The future after each player decision is simulated and fictional.

Core fantasy:

> Lead a real, diverse Indonesia through interconnected crises where every decision has regional, national, social, economic, environmental, and cultural consequences.

Core loop:

> Observe → Understand → Decide → Allocate → Simulate → React → Adapt → Legacy

This repository is the **single source of truth** for game design, research rules, data standards, technical principles, content schemas, AI usage, and quality gates.

## Before doing anything

Claude Code must read, in this order:

1. `CLAUDE.md`
2. `AGENTS.md`
3. `docs/00_PROJECT_CHARTER.md`
4. `docs/01_PRD.md`
5. `docs/02_GDD.md`
6. `docs/03_COMPETITION_REQUIREMENTS.md`
7. `docs/04_DATA_RESEARCH_SPEC.md`
8. `docs/05_CULTURAL_RESEARCH_SPEC.md`
9. `docs/06_CASE_RESEARCH_SPEC.md`
10. `docs/07_SIMULATION_SPEC.md`
11. `docs/08_MAP_AND_GIS_SPEC.md`
12. `docs/09_CONTENT_DATA_SCHEMA.md`
13. `docs/10_TECHNICAL_ARCHITECTURE_PRINCIPLES.md`
14. `docs/11_SAVE_SYSTEM_SPEC.md`
15. `docs/12_AI_USAGE_AND_PROVENANCE.md`
16. `docs/13_ASSET_PIPELINE.md`
17. `docs/14_QA_ACCEPTANCE.md`
18. `docs/15_ROADMAP.md`
19. `docs/16_RESEARCH_EXECUTION_PLAN.md`
20. `docs/17_RISK_REGISTER.md`
21. `docs/18_GLOSSARY.md`
22. `prompts/MASTER_EXECUTION_PROMPT.md`

Do not skip documents because they appear redundant. Their separation is intentional.

## Repository policy

- Do not invent factual data.
- Do not silently replace an official source with a lower-quality source.
- Do not silently overwrite raw data.
- Do not mix real facts with simulated outcomes without explicit labeling.
- Do not treat a province as culturally homogeneous.
- Do not use sacred or sensitive cultural material as a game mechanic without explicit suitability review.
- Do not hardcode content into gameplay controllers when it can be represented as data.
- Do not start large-scale gameplay coding before the research/data contracts are established.
- Never expose secrets or API keys in Git.

## Planned project layout

```text
NUSANTARA/
├── CLAUDE.md
├── AGENTS.md
├── README.md
├── ITCAS_2026_Game_Development_Guidebook.pdf
├── ITCAS_2026_Poster.png
├── docs/
├── prompts/
├── game_design/
├── research/
│   ├── cases/
│   ├── culture/
│   ├── data/
│   ├── reports/
│   └── sources/
├── data/
│   ├── raw/
│   ├── processed/
│   ├── normalized/
│   ├── catalog/
│   ├── schemas/
│   └── snapshots/
└── scripts/
```

## Definition of complete research

"Complete" means maximum defensible coverage of publicly accessible relevant data, with explicit provenance and an explicit gap registry. It does **not** mean claiming that no dataset anywhere can ever be missing.

## Platform policy

This repository is **desktop-first**. Do not redesign the core experience for mobile. The IT-CAS 2026 guidebook presently states that both APK and EXE are required, so Android remains a secondary export/compliance concern rather than the primary design target. See `docs/26_DESKTOP_FIRST_TECH_STACK_POLICY.md`.

## Tactical implementation prompt

For a focused Claude Code implementation session, use `prompts/DESKTOP_FIRST_EXECUTION_PROMPT.md`.
