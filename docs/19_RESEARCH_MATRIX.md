# 19 MASTER RESEARCH MATRIX

This document turns the broad research ambition into an actionable inventory. Claude Code should expand it during discovery with actual dataset IDs, URLs, access methods, and current availability.

| Domain | Required concepts | Preferred source families | Geographic target | Priority |
|---|---|---|---|---|
| Geography | boundary, code, name, area, geometry, centroid | BIG | province + regency/city | P0 |
| Population | population, density, age, sex, growth | BPS | regency/city | P0 |
| Human development | IPM, schooling, health, labor | BPS + ministries | regency/city | P0 |
| Economy | PDRB, growth, per-capita, sectors | BPS | regency/city | P0 |
| Fiscal | APBN, APBD, PAD, transfer, spending | Kemenkeu/DJPK | national + local | P0 |
| Agriculture | harvested area, production, productivity | BPS + agriculture ministry | province + local where available | P0 |
| Plantation | commodity areas/output | BPS + agriculture ministry | province + local where available | P1 |
| Fisheries | capture, aquaculture, marine assets | KKP | province + WPP + local where available | P1 |
| Forestry | forest area, cover, timber, conservation | Ministry of Forestry | province + local where available | P1 |
| Minerals | resources, reserves, production, processing | ESDM/Geological Agency | province/asset | P0 |
| Energy | generation, capacity, fuel, renewables | ESDM/PLN/public official sources | province | P0 |
| Infrastructure | roads, ports, airports, rail, utilities | ministries/BPS | local | P0 |
| Industry | establishments, manufacturing, industrial estates | BPS/ministry | province/local | P1 |
| Tourism | destinations, visitors, accommodation | BPS/tourism ministry | province/local | P1 |
| Education | schools, teachers, students, participation | education datasets/BPS | local | P1 |
| Health | hospitals, puskesmas, health workers, access | health datasets/BPS | local | P1 |
| Social | poverty, inequality, employment, protection | BPS/social ministry | local | P0 |
| Environment | air/water, conservation, waste, emissions | environment ministry/BPS | local/province | P1 |
| Disaster | hazards, history, losses, exposure | BNPB/BMKG | local | P0 |
| Digital | internet, BTS, connectivity, digital government | communications ministry/BPS | local | P1 |
| Culture | ethnic groups, language, adat, WBTb, knowledge | culture ministry/SPKT/Badan Bahasa/BPS | all available levels | P0 |

## P0 rule

P0 data is necessary for the first credible simulation baseline.

## P1 rule

P1 data materially improves depth but can be integrated after the core world state is stable.

## Source discovery rule

Claude Code must replace placeholders with actual current official dataset references and record availability status.
