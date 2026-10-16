# 01 PRODUCT REQUIREMENTS DOCUMENT

## 1. Product summary

NUSANTARA is a 2D Indonesian governance simulation where a fictional president, Nara Adinata, manages the real geographic and socio-economic complexity of Indonesia.

The player does not control a fantasy nation. The player interacts with real Indonesian provinces and regencies/cities, uses grounded regional data, and faces cases derived from real events.

## 2. Target audience

Primary:

- older teenagers
- university students
- young adults
- people interested in strategy, simulation, Indonesia, policy, geography, and civic learning

The game must remain understandable for players with no prior economics or public policy background.

## 3. Player promise

> "Kamu memimpin Indonesia, tetapi kamu tidak pernah memiliki pilihan yang benar-benar gratis."

## 4. Core player loop

```text
PANTAU KONDISI
    ↓
IDENTIFIKASI MASALAH
    ↓
BACA BRIEFING
    ↓
ANALISIS DATA
    ↓
PILIH KEBIJAKAN / TINDAKAN
    ↓
ALOKASI SUMBER DAYA
    ↓
SIMULASI WAKTU
    ↓
DAMPAK REGIONAL
    ↓
DAMPAK NASIONAL
    ↓
SENTIMEN MASYARAKAT
    ↓
CASE BERIKUTNYA
```

## 5. Simulation time

Baseline:

- 1 internal tick = 1 month
- 3 ticks = 1 quarter
- 4 quarters = 1 year
- 5 years = 20 major turns / quarters
- 5 years = 60 monthly simulation ticks

The architecture may support more turns, but the core complete-run target is five years.

## 6. Save

- fully offline
- manual save anytime
- multiple save slots
- autosave
- quicksave
- save survives restart
- no fixed hardcoded low slot count
- actual limit is practical device storage

## 7. Map interaction

The player can:

- pan the map
- zoom
- click regions
- inspect provinces
- inspect regencies/cities
- access region details
- return to national view

The map should feel strategy-game-like while preserving real geography.

## 8. Core national indicators

The first dashboard should emphasize:

- Anggaran/Fiskal
- Ekonomi
- Kesejahteraan
- Kepercayaan publik
- Stabilitas
- Lingkungan

The backend may contain substantially more variables.

## 9. Resource categories

### Fiscal resources

- budget
- revenue
- debt capacity
- transfer capacity

### Production resources

- food
- energy
- industrial output
- selected strategic commodities

### Natural capital

- forests
- mineral resources/reserves
- fisheries
- oil/gas
- geothermal potential
- other documented natural assets

### Human capital

- population
- labor force
- education
- health
- productivity proxies

### Capacity

- infrastructure
- logistics
- industrial capacity
- public-service capacity

## 10. Stakeholders

At minimum:

- citizens
- farmers
- workers
- businesses
- local governments
- indigenous/local communities
- civil society
- academia/experts
- cabinet/government institutions

Stakeholders do not all need to be individual NPCs. They may be represented as population groups or regional state variables.

## 11. Sentiment system

Regional sentiment is dynamic and derived from current conditions. It must not be a random cosmetic bar.

Baseline states:

- Sangat Mendukung
- Mendukung
- Stabil
- Khawatir
- Tidak Puas
- Marah
- Kritis

The internal model can use a 0-100 score and a state mapping.

## 12. Historical memory

The game must remember major government decisions and allow future cases/dialogue to react to prior choices.

## 13. Victory / ending

The primary ending product is:

# WARISAN PEMERINTAHAN

The ending reports multiple dimensions such as:

- Kemakmuran Ekonomi
- Kesejahteraan Sosial
- Stabilitas Nasional
- Kesehatan Lingkungan
- Pemerataan Wilayah
- Ketahanan Budaya

A run may be broadly positive, mixed, or crisis-level without reducing the whole game to one simplistic score.

## 14. Information UX

Three layers:

### Ringkas
Immediate dashboard values.

### Wilayah
Region-level indicators and context.

### Data Mendalam
Source, methodology, detailed values, reference years, and provenance.

## 15. Education strategy

The game teaches through decision-making and consequences, not textbook exposition.

## 16. Scope firewall

A feature is justified only if it materially improves one or more of:

- theme relevance
- creativity
- gameplay/UX
- stability/performance
- impact/potential

Features with weak value and high complexity should be postponed.
