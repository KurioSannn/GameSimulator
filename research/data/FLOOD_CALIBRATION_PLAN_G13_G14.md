# G-13 / G-14 flood calibration plan and source inventory

Written 2026-10-06, before implementation, as requested.

## 1. Source inventory (verified 2026-10-06)

| Source | Institution | Content | Resolution | Years | Access | Status |
|---|---|---|---|---|---|---|
| Buku IRBI 2024 | BNPB | official risk index, multi-hazard + per-hazard (flood) | kab/kota (flood: 397 listed) | 2024 | PDF on inarisk.bnpb.go.id | **ingested** |
| `kompilasi-data-jumlah-dan-dampak-kejadian-bencana-2024` | BNPB Pusdatinkom (data.bnpb.go.id, CKAN, license ODbL) | events + deaths, missing, injured, affected, displaced, houses/schools/health facilities/worship/offices/shops/factories/bridges damaged | kab/kota (14 tables) | 2024 | CKAN **DataStore API** (`datastore_active`). Direct XLSX download returns a Cloudflare challenge, which we do not bypass | to ingest |
| `jumlah-kejadian-dan-dampak-bencana-tahun-2000`, `-2001` | BNPB Pusdatinkom (CC-BY) | events + impacts | kab/kota (per-province XLSX) | 2000–2001 | CKAN (check DataStore; downloads may be challenged) | to check |
| `jumlah-kejadian-dan-dampak-bencana-tahun-2002` … `-2023` | BNPB Pusdatinkom (CC-BY) | events + impacts (`stat_by_wil_<prov>_<year>.xlsx`) | kab/kota | 2002–2023 | linked public **Google Drive** folders. Drive robots.txt disallows the download endpoints (`/uc`, `drive.usercontent.google.com`), so **no automated download** | **human download needed** |
| `kompilasi-data-kejadian-dan-dampak-bencana-2025` | BNPB Pusdatinkom | events + impacts | province (kab/kota to check) | 2025 (partial year) | CKAN | to check |
| BNPB ArcGIS (InaRISK) | BNPB | hazard/risk layers | raster/kab | — | HTTP 521 (down) | blocked |

## 2. Variables (explicit names; REAL vs DERIVED never share a name)

**REAL observations** (`data/normalized/observations/`):
- `official_irbi_flood_score` (renamed from `irbi_flood`) and `official_irbi_total_score` (from `irbi_total`): unit "skor IRBI", period 2024. Official **risk** index, not hazard and not exposure.
- `bnpb_flood_events`: recorded flood events (BNPB category BANJIR), count per kab/kota per year.
- `bnpb_flood_affected`, `bnpb_flood_displaced`, `bnpb_flood_deaths`, `bnpb_flood_houses_damaged`: per kab/kota per year, **only if the tables break impacts down by hazard type**; otherwise all-hazard impacts are stored under `bnpb_all_*` and never relabeled as flood.

**DERIVED game variables** (`game/data/baseline.json`):

| Concept | Variable | Rule | Missing data |
|---|---|---|---|
| Baseline flood risk profile | `flood_risk_profile` | 100 × official IRBI flood score / 36 | UNCALIBRATED (neutral 50) |
| Historical flood frequency | `flood_frequency` (events/year) | mean of `bnpb_flood_events` over available years (≥1); coverage years recorded | province median as PROVINCE_PROXY; else national median as UNCALIBRATED. **Never 0 by default.** |
| Event probability | computed per tick | Poisson: P(≥1 event in month m) = 1 − exp(−λ·s_m), with λ = `flood_frequency` and s_m the month's share of the seasonal profile | — |
| Severity | per event, computed | Exp(mean μ) × severity_scale_i, capped | μ is a model value until population allows an empirical anchor (see §4) |
| Severity scale (vulnerability/capacity composite) | derived from `flood_risk_profile` | 0.5 + profile/100 (median IRBI ≈ 1.0) | 1.0 (UNCALIBRATED) |
| Exposure | not separately calibrated | no official exposure-only source ingested; the IRBI index already contains exposure | documented gap |
| Mitigation | `flood_protection` | built during the term (cases, disaster budget); 0 at start | — |
| Infrastructure resilience | `infrastructure` | impact × (1.25 − 0.5 × infrastructure/100) (infrastructure 50 → ×1.0) | existing variable (UNCALIBRATED baseline) |
| Damage / recovery | `damage`, recovery step | unchanged | — |

Impact of one flood:
`impact = severity_draw × severity_scale × (1 − 0.75 × protection/100) × resilience(infrastructure)`

Mitigation changes **future** outcomes only, and only when floods occur. There is no permanent bonus.

## 3. G-14 resolution
Regions without an IRBI flood score use BNPB event history for frequency, keep a neutral severity scale, and are labeled. Regions with neither get a province or national median frequency, labeled PROVINCE_PROXY or UNCALIBRATED. This avoids artificial suppression (no forced 0) without fabricating a risk score.

## 4. Severity calibration (§6 of the request)
- 2024 impact tables give **annual totals per kab/kota**, not per-event records. An empirical per-region "mean affected per event" = affected / events is possible.
- Turning that into damage points (our damage index = share of regional capacity impaired) needs **regional population**, which is blocked on the BPS key (G-01).
- Until then: μ stays a labeled model value, normalized so that expected national flood damage stays at the level validated in the IRBI milestone (an untouched term ≈ −5 national sentiment).
- Rule to activate once population exists: `points_per_event_i = 100 × (affected_i / events_i) / population_i`.

## 5. Tests to add
- Region with IRBI and history.
- Region without IRBI but with history (floods possible).
- Region with neither (frequency is a labeled proxy; floods possible, i.e. **not suppressed**).
- Mitigation reduces future damage for identical events.
- Resilience (infrastructure) reduces impact.
- CASE-0001 gold-standard tests still pass (golden master regenerated with stated reason).

## 6. Human actions
1. Download BNPB's 2002–2023 Drive folders in a browser (links in each CKAN package), unzip into `data/raw/bnpb/drive_manual/<year>/`. The pipeline will ingest them and record checksums. This makes `flood_frequency` genuinely multi-year.
2. BPS key, which enables the population-anchored severity.
