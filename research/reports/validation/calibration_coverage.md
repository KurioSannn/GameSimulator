# Calibration coverage

Generated 2026-10-23T03:43:22+00:00 · snapshot `SNAP-2026-10-DEV1`

Variable status: {'REAL_OFFICIAL': 3, 'UNCALIBRATED': 5, 'BY_DESIGN': 10, 'DERIVED': 2}

| Sim variable | Rule | Period | REAL | Province proxy | Uncalibrated | Note |
|---|---|---|---|---|---|---|
| `population` | identity(pop_total) | 2026 | 514/514 | 0 | 0 | period coverage 100% |
| `food_supply` | by design | — | — | — | — | Computed every tick from food capacity, logistics and damage; the starting value is overwritten in the first month. |
| `price_level` | by design | — | — | — | — | Index defined as 100 at game start. |
| `infrastructure` | ratio_pct(road_good_km, road_total_km) | — | 0/514 | 0 | 514 | inputs not yet ingested: road_good_km, road_total_km |
| `damage` | by design | — | — | — | — | No unrecovered simulated damage at game start. |
| `welfare_base` | identity(ipm) | 2024 | 514/514 | 0 | 0 | period coverage 100% |
| `trust` | by design | — | — | — | — | Starts neutral for the same reason as sentiment_base. |
| `sentiment_base` | by design | — | — | — | — | No official measure of regional support for a fictional president exists; deriving it from proxies risks stereotyping regions. |
| `sentiment` | by design | — | — | — | — | Starts at sentiment_base. |
| `flood_protection` | by design | — | — | — | — | Additional flood protection built during the term. Baseline protective capacity is already embedded in the IRBI risk score used for flood_exposure, so starting at 0 avoids double counting. |
| `flood_damage_last` | by design | — | — | — | — | Computed each tick. |
| `flood_risk_profile` | scaled(official_irbi_flood_score) | 2024 | 397/514 | 0 | 117 | period coverage 77% |
| `flood_frequency` | gamma_poisson_rate(bnpb_flood_events) | 2024 | 450/514 | 51 | 13 | alpha=1.174, beta=0.370 yr, national mean 3.173/yr |
| `flood_events_last` | by design | — | — | — | — | Computed each tick. |
| `fire_prevention` | by design | — | — | — | — | Additional prevention built during the term; baseline capacity is not measured (no official kab/kota index ingested). |

Variables neutral by design: `price_level`, `damage`, `sentiment_base`, `sentiment`, `trust`, `flood_damage_last`, `flood_protection`, `flood_events_last`, `fire_prevention`, `food_supply`
