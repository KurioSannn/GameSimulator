# VARIABLE INVENTORY & SOURCE MAPPING (calibration sprint)

Started 2026-10-05. This is the contract between **real source data** and the **simulation**.
Dataset/variable IDs are filled **only after discovery against the live source**, never guessed. Status:
`MAPPED` (definition known, dataset not yet retrieved) · `RETRIEVED` · `VALIDATED` · `BLOCKED` (access) · `GAP` (no official source found yet).

## Layer model (D-020)

```text
REAL SOURCE DATA      data/raw/<source>/...                  immutable captures + MANIFEST checksums
  │  (connector: parse only, no interpretation)
  ▼
REAL NORMALIZED       data/normalized/observations/*.jsonl   one row = one official value + provenance  [REAL_OFFICIAL]
  │  (calibration/variable_map.json: documented transforms)
  ▼
DERIVED GAME DATA     game/data/baseline.json                game-model starting values + per-region status [DERIVED]
  │  (Godot runtime)
  ▼
SIMULATED STATE       SimWorld (saves)                       changed by decisions/ticks                  [SIMULATED]
FICTIONAL CONTENT     case briefings, dialogue, Nara         never presented as fact                     [FICTIONAL]
```

## A. Observation variables (real, as published)

| obs_variable_id | Concept (Bahasa) | Definition (source wording to be confirmed on retrieval) | Unit | Best source | Resolution | Expected latest period | Status |
|---|---|---|---|---|---|---|---|
| `pop_total` | Jumlah penduduk | Mid-year population (BPS projection based on SP2020) | jiwa | BPS (WebAPI dynamic table) | kab/kota | 2024 or 2025 | BLOCKED (key) |
| `pop_dkb` | Jumlah penduduk (administrasi) | Registered population in Data Kependudukan Bersih (semester) | jiwa | Kemendagri Dukcapil | kab/kota | 2025 S1 | MAPPED (alt; different definition — never merged with `pop_total`) |
| `area_km2` | Luas wilayah | Polygon area of official boundary | km² (to verify, G-03) | BIG geodatabase `luaswh` | kab/kota | edition 2023-09 | RETRIEVED |
| `ipm` | Indeks Pembangunan Manusia | UNDP-method HDI (health, education, expenditure), BPS 2010+ method | indeks 0–100 | BPS | kab/kota | 2024/2025 | BLOCKED (key) |
| `poverty_p0` | Persentase penduduk miskin | Share of population below poverty line (Susenas March) | persen | BPS | kab/kota | 2024/2025 | BLOCKED (key) |
| `unemployment_tpt` | Tingkat Pengangguran Terbuka | Open unemployment rate (Sakernas August) | persen | BPS | kab/kota | 2024/2025 | BLOCKED (key) |
| `pdrb_adhb` | PDRB atas dasar harga berlaku | Gross regional product, current prices | juta rupiah | BPS | kab/kota | 2024 | BLOCKED (key) |
| `pdrb_adhk` | PDRB atas dasar harga konstan 2010 | Constant 2010 prices | juta rupiah | BPS | kab/kota | 2024 | BLOCKED (key) |
| `pdrb_growth` | Laju pertumbuhan PDRB | y/y growth of ADHK | persen | BPS | kab/kota | 2024 | BLOCKED (key) |
| `rice_production` | Produksi padi | Rice production (Gabah Kering Giling), KSA method | ton GKG | BPS | kab/kota | 2024 | BLOCKED (key) |
| `rice_harvest_area` | Luas panen padi | Harvested area (KSA) | hektar | BPS | kab/kota | 2024 | BLOCKED (key) |
| `road_condition_good` | Panjang jalan kondisi baik | Road length by condition, kab/kota authority | km | BPS (from PU/daerah) | kab/kota | 2023/2024 | BLOCKED (key) |
| `electrification` | Rasio elektrifikasi / rumah tangga ber-PLN | Households with electricity | persen | BPS (Susenas) / ESDM | provinsi (kab/kota TBD) | 2024 | MAPPED |
| `apbd_revenue` | Pendapatan daerah | Realized/budgeted regional revenue | rupiah | Kemenkeu DJPK | provinsi, kab/kota | 2025/2026 | BLOCKED (DNS/timeout) |
| `apbd_pad` | Pendapatan Asli Daerah | Own-source revenue | rupiah | Kemenkeu DJPK | kab/kota | 2025/2026 | BLOCKED |
| `apbd_spending` | Belanja daerah | Regional expenditure | rupiah | Kemenkeu DJPK | kab/kota | 2025/2026 | BLOCKED |
| `apbn_revenue` / `apbn_spending` | Pendapatan / Belanja negara | APBN totals (UU APBN) | rupiah | Kemenkeu (UU APBN / Nota Keuangan) | national | 2026 | MAPPED |
| `forest_area` | Luas kawasan hutan | Designated forest area by function | hektar | Kementerian Kehutanan | provinsi | latest | MAPPED (host unreachable) |
| `fish_capture` | Produksi perikanan tangkap | Capture fisheries production | ton | KKP | provinsi/kab | latest | MAPPED (host unreachable) |
| `disaster_risk_index` | Indeks Risiko Bencana (IRBI) | BNPB composite risk index | indeks | BNPB (IRBI publication / InaRISK) | kab/kota | 2023/2024 | MAPPED |

## B. Simulation variables (derived) and their calibration rule

| Sim variable | Calibration rule (DERIVED) | Inputs | Fallback per region | Justification |
|---|---|---|---|---|
| `population` | = `pop_total` (no transform) | pop_total | none: stays UNCALIBRATED; national weights fall back to equal | Real stock in source units (D-009) |
| `welfare_base` / `welfare` | = `ipm` (0–100 composite used directly as the structural welfare index) | ipm | province IPM, labeled `PROVINCE_PROXY` | IPM is the official composite of health, education and living standard; no invented weighting |
| `food_capacity` | = (rice_production × milling conversion × per-capita need⁻¹) ÷ population, capped 0–5 | rice_production, pop_total, conversion factor and consumption norm from an official publication | UNCALIBRATED | Conversion/consumption constants must themselves be sourced (BPS/Kementan) before use |
| `infrastructure` | = 100 × road_good_km ÷ road_total_km | road_condition_good, road total | province ratio as `PROVINCE_PROXY` | Share of road length in good condition; transparent and bounded |
| `services` | TBD (health/education facility density) | puskesmas, schools per 10k pop | UNCALIBRATED | needs facility datasets |
| `environment` | TBD (forest cover share, air quality) | forest_area, area_km2 | UNCALIBRATED | |
| `sentiment_base`, `trust` | **stay neutral by design** (no official measure of regional support for a fictional president exists) | — | neutral 55 | Inventing regional "support" from proxies would be a stereotype risk |
| `price_level` | 100 at start by definition (index) | — | — | Index relative to the starting state |
| `fiscal_space` (national) | from APBN discretionary share | apbn_* | UNCALIBRATED | |

## C. Conflicts policy

- Two sources for the same concept (e.g., BPS projection vs Dukcapil registration) get **different `obs_variable_id`s**. A calibration rule picks one explicitly, and the other is kept for the conflict report.
- Values that differ by more than 5% between sources for the same region and period are listed in `research/reports/validation/conflicts_<date>.md`.

## D. Resolution policy

- Observations are stored at the resolution actually published.
- A kab/kota sim value derived from a province observation gets per-region status `PROVINCE_PROXY` and is labeled "proksi provinsi" in the UI. It is never labeled as kab/kota data.

## E. Reconciliation: official variables ↔ simulation variables (updated 2026-10-05, milestone 2)

The two lists are **not one-to-one, by design**. Official variables describe the real world as published. Simulation variables are the game model's state. One official variable may feed several simulation variables, several official variables may combine into one, and some exist on only one side.

### E1. Every official variable → where it goes

| # | Official variable | → Simulation variable | Resolution | Unit | Expected ref. year | Calibration rule | Current status |
|---|---|---|---|---|---|---|---|
| 1 | `pop_total` (BPS) | `population` | kab/kota | jiwa | 2024/2025 | identity | BLOCKED (key/host) |
| 2 | `pop_dkb` (Dukcapil) | — (conflict check vs #1 only) | kab/kota | jiwa | 2025 S1 | none; never merged | BLOCKED (host) |
| 3 | `area_km2` (BIG) | — (reference fact; future density = pop/area) | kab/kota | km² | 2023-09 | shown as REAL fact | **RETRIEVED** (514/514) |
| 4 | `ipm` (BPS) | `welfare_base` → `welfare` (copy) | kab/kota | indeks | 2024/2025 | identity, province proxy fallback | BLOCKED |
| 5 | `poverty_p0` (BPS) | — now; planned `poverty` (welfare split) | kab/kota | persen | 2024/2025 | reference fact first | BLOCKED |
| 6 | `unemployment_tpt` (BPS) | — now; planned `employment` | kab/kota | persen | 2024/2025 | reference fact first | BLOCKED |
| 7 | `pdrb_adhb` (BPS) | — now; planned `economic_output` | kab/kota | juta rupiah | 2024 | reference fact first | BLOCKED |
| 8 | `pdrb_adhk` (BPS) | — (growth base for #9) | kab/kota | juta rupiah | 2024 | — | BLOCKED |
| 9 | `pdrb_growth` (BPS) | — now; planned growth driver | kab/kota | persen | 2024 | — | BLOCKED |
| 10 | `rice_production` (BPS) | `food_capacity` (with #1 and sourced constants) | kab/kota | ton GKG | 2024 | per-capita ratio | BLOCKED |
| 11 | `rice_harvest_area` (BPS) | — (productivity context) | kab/kota | ha | 2024 | — | BLOCKED |
| 12 | `road_condition_good` (BPS) | `infrastructure` → `logistics` (copy) | kab/kota | km | 2023/2024 | ratio_pct with road total | BLOCKED |
| 13 | `electrification` | — now; planned `energy_access` | provinsi | persen | 2024 | — | MAPPED |
| 14 | `apbd_revenue` (DJPK) | — now; planned regional fiscal | kab/kota | rupiah | 2025/2026 | — | BLOCKED (host) |
| 15 | `apbd_pad` (DJPK) | — now; planned regional fiscal | kab/kota | rupiah | 2025/2026 | — | BLOCKED |
| 16 | `apbd_spending` (DJPK) | — now; planned regional fiscal | kab/kota | rupiah | 2025/2026 | — | BLOCKED |
| 17 | `apbn_revenue` / `apbn_spending` (+ spending by function) | national budget pool + sector base shares (`game/data/budget.json`) | national | rupiah | 2026 | see `data/calibration/budget_map.json` | MAPPED |
| 18 | `forest_area` | — now; planned `environment` input | provinsi | ha | latest | — | MAPPED (host) |
| 19 | `fish_capture` | — now; planned food/marine capacity | provinsi/kab | ton | latest | — | MAPPED (host) |
| 20 | `irbi_flood` (BNPB IRBI 2024 flood risk) + `irbi_total` (multi-hazard, reference fact) | `flood_exposure` | kab/kota | skor IRBI | 2024 | 100 × score / 36 | **RETRIEVED** (flood 397/514 + 117 NOT_PUBLISHED; total 514/514) |

### E2. Every simulation variable → where its starting value comes from

| Simulation variable | Source of starting value | Why |
|---|---|---|
| `population` | #1 | real stock |
| `welfare_base`, `welfare` | #4 | official composite |
| `food_capacity` | #10 + #1 + sourced constants | derived ratio |
| `infrastructure`, `logistics` | #12 | derived ratio |
| `flood_exposure` | #20 (IRBI 2024), DERIVED for 397/514; 0 + UNCALIBRATED for the 117 not listed (G-14) | hazard |
| `services`, `environment` | not yet mapped (facility density, forest cover) | **inventory gap**, to add |
| `flood_protection` | 0 by design: protection added during the term; baseline capacity is inside IRBI risk (D-030) | model state |
| `food_supply`, `flood_damage_last` | computed every tick | derived state, never calibrated |
| `price_level` (=100), `damage` (=0) | defined values at game start | index or stock definitions |
| `sentiment_base`, `sentiment`, `trust` | neutral by design (D-021) | no official measure exists |

### E3. Explaining "20 official vs 14 (now 17) simulation variables"

- Official variables that map to a simulation variable today: **6** (#1, #4, #10, #12, #17, #20), driving `population`, `welfare_base`/`welfare`, `food_capacity`, `infrastructure`/`logistics`, the national budget, and `flood_exposure`.
- Official variables that are **reference facts or support inputs only** (shown in the UI or used inside another rule, not simulation state): **4** (#2 conflict check, #3, #8, #11).
- Official variables reserved for **planned simulation variables not yet in the model**: **10** (#5, #6, #7, #9, #13–16, #18, #19). Each enters only when its mechanic is built; adding state without a mechanic would be decoration.
- Simulation variables that by design **never take an official value**: 8 (`food_supply`, `flood_damage_last`, `logistics` and `welfare` as copies, `price_level`, `damage`, `sentiment`, `sentiment_base`, `trust`; some overlap with copies). They are model state, not measurements.
- Simulation variables with **no mapped official source yet** (a real inventory gap): `services`, `environment`, `flood_protection`. Added to the gap registry as G-12.

So the sentence "14 of 14 placeholder" meant that no official input had been ingested yet. Of the simulation variables, only 6 groups are designed to receive official values; the rest are model state or neutral by design.

## F. Flood variables after D-032 (2026-10-06)
| Official observation | Unit | Resolution | Year(s) | → Derived / simulated variable | Rule | Status |
|---|---|---|---|---|---|---|
| `official_irbi_flood_score` (BNPB IRBI 2024) | skor IRBI | kab/kota (397 + 117 NOT_PUBLISHED) | 2024 | `flood_risk_profile` (indeks 0–100, turunan) | 100 × score/36; missing → 50 UNCALIBRATED | RETRIEVED |
| `bnpb_flood_events` (BNPB CKAN) | kejadian | kab/kota (450) | 2024 (2002–2023 pending G-15) | `flood_frequency` (kejadian/tahun) | Gamma–Poisson, province prior | RETRIEVED |
| `bnpb_flood_affected`, `_displaced`, `_deaths`, `_missing`, `_injured`, `_houses_damaged`, `_schools_damaged`, `_health_facilities_damaged`, `_bridges_damaged` | jiwa / unit | kab/kota (450) | 2024 | (severity anchor once population exists) | `100 × affected/events/population` (not yet active) | RETRIEVED |
| `official_irbi_total_score` | skor IRBI | kab/kota (514) | 2024 | reference fact only | — | RETRIEVED |
