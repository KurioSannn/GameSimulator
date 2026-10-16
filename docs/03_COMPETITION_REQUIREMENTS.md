# 03 COMPETITION REQUIREMENTS: IT-CAS 2026

## Source of truth

Primary competition reference in this project:

`ITCAS_2026_Game_Development_Guidebook.pdf`

The extracted guidebook states:

- competition: IT-Competition AMIKOM Surakarta (IT-CAS) 2026
- category: Game Development (Mahasiswa)
- top-line theme: **"Inovasi Cerdas untuk Indonesia Emas"**
- descriptive framing also uses **"Kearifan Lokal untuk Indonesia Emas"**
- team: **3 students**
- submission formats: Android `.apk` and Windows `.exe`
- APK maximum size: 250 MB
- EXE maximum size: 1 GB
- game should run without requiring extra software installation
- include a gameplay guide PDF
- disclose technology/tools used
- AI use is allowed as an assistive tool but cannot replace the entire creative process; substantive AI use must be disclosed; the team remains responsible for originality, quality, legality, etc.; the team should be able to explain the process and show evidence if requested
- submission includes download links for APK and EXE plus gameplay PDF

## Judging weights from the guidebook

| Criterion | Weight |
|---|---:|
| Kesesuaian Tema | 15% |
| Ide dan Kreativitas | 20% |
| Gameplay dan User Experience | 20% |
| Stabilitas dan Performa Game | 20% |
| Visual dan Audio | 10% |
| Dampak / Potensi | 15% |

## Timeline stated in the guidebook

- registration deadline: 15 November 2026
- work submission deadline: 15 November 2026
- winner announcement: 12 December 2026

## Known source inconsistencies

The guidebook description contains an apparent text inconsistency referring to "IT-CAS 2025" while the document is for IT-CAS 2026. Do not silently rewrite the guidebook. Treat the 2026 guidebook as the competition baseline and verify current organizer announcements before final submission.

The guidebook also has a theme wording inconsistency between its headline and descriptive section. NUSANTARA is intentionally designed to satisfy both: **smart innovation for Indonesia's future + local wisdom.**

## Engineering response to the rubric

We should explicitly optimize for:

- memorable core mechanic for creativity
- decision-consequence depth for gameplay
- stable and optimized full-region simulation for performance
- coherent visual/audio identity despite modest asset scope
- educational/cultural relevance for impact

## AI compliance rule

Maintain a transparent AI usage log covering Claude Code, ChatGPT, GPT-based asset ideation/generation, music generation, voice generation, and any other AI tools actually used.

Never falsify AI usage or human authorship.

## Project implementation priority

For internal development, **Windows `.exe` is the primary target**. UX, map interaction, performance profiling, input, and feature validation should be completed against the desktop build first. The APK requirement from the guidebook remains a release/compliance concern unless the organizer officially clarifies otherwise. Do not treat this priority as permission to ignore the stated submission requirement.
