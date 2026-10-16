# 04 DATA RESEARCH SPECIFICATION

## Goal

Build a **maximum-coverage Indonesia World Dataset** from publicly accessible, credible, and preferably official sources. The objective is not merely to collect numbers, but to create a reproducible evidence layer for the simulation.

## Research principles

1. Official first.
2. Current/latest available first, without discarding important historical datasets.
3. Highest available geographic resolution.
4. Preserve source units and definitions.
5. Never fabricate missing values.
6. Preserve raw data.
7. Track every transformation.
8. Track every gap.
9. Distinguish stock, flow, potential, reserve, capacity, and production.
10. Distinguish real baseline data from simulated future state.

## Source priority candidates

These are candidates to investigate and verify, not a license to assume availability:

- Badan Informasi Geospasial (BIG)
- Badan Pusat Statistik (BPS)
- Satu Data Indonesia / data.go.id
- Kementerian Keuangan / DJPK
- Badan Geologi / ESDM
- Kementerian Energi dan Sumber Daya Mineral
- Kementerian Kehutanan
- Kementerian Kelautan dan Perikanan
- Kementerian Pertanian
- Kementerian Kebudayaan / relevant cultural systems
- Badan Bahasa
- BMKG
- BNPB
- Kementerian PUPR / relevant infrastructure systems
- Kementerian Perhubungan
- Komdigi / relevant digital infrastructure sources
- Ministry datasets for education and health
- Academic repositories when government coverage is insufficient
- Reputable news for historical case documentation

## Domain inventory

### A. Geography

- region codes
- region names
- administrative hierarchy
- geometry
- centroid
- area
- coastline
- islands
- neighboring regions
- spatial relationships

### B. Demography

- population
- density
- growth
- age structure
- sex
- households
- migration where available
- labor force
- dependency ratio

### C. Human development

- IPM/HDI
- schooling
- health indicators
- labor participation
- unemployment
- poverty
- inequality
- productivity proxies

### D. Economy

- PDRB/GDP regional values
- growth
- per-capita output
- sector composition
- agriculture
- manufacturing
- services
- trade
- investment
- tourism
- exports/imports when available

### E. Fiscal

- APBN
- state revenue
- state spending
- deficit
- debt/financing
- transfers to regions
- APBD
- PAD
- local revenue
- local spending
- capital expenditure
- fiscal balance
- fiscal dependence

### F. Agriculture

- harvested area
- production
- productivity
- crops
- horticulture
- livestock
- irrigation
- agricultural land

### G. Plantation

As many documented commodities as available, e.g.:

- palm oil
- rubber
- coffee
- cocoa
- coconut
- tea
- sugarcane
- tobacco
- clove
- nutmeg
- pepper
- sago
- cashew
- other documented crops

### H. Fisheries and marine

- capture production
- aquaculture
- commodities
- mariculture
- seaweed
- fishery infrastructure
- ports
- WPP-related context
- marine economic indicators

### I. Forestry

- forest area
- forest cover
- production forest
- conservation forest
- timber potential
- timber production
- biomass/carbon proxies where officially documented
- deforestation/change indicators

### J. Minerals and extractives

- coal
- nickel
- gold
- copper
- bauxite
- tin
- iron
- manganese
- non-metal minerals
- rocks
- oil
- gas
- geothermal
- resources
- reserves
- production
- extraction status
- processing/smelting capacity

### K. Energy

- installed generation capacity
- electricity production
- electricity consumption
- electrification
- fuel production
- geothermal
- hydro
- solar
- wind
- biomass
- other renewable potential

### L. Industry

- industrial establishments
- manufacturing
- industrial capacity
- labor
- downstream processing
- industrial estates

### M. Infrastructure

- roads
- road condition
- bridges
- rail
- airports
- ports
- terminals
- logistics
- internet
- BTS
- water
- sanitation
- irrigation
- dams/reservoirs
- public facilities

### N. Tourism

- destinations
- visitors
- accommodation
- tourism employment
- cultural/nature tourism

### O. Environment

- air quality
- water quality
- protected areas
- waste
- emissions
- land degradation
- environmental risk

### P. Disaster and resilience

- flood risk
- earthquake hazard
- tsunami hazard
- volcanic hazard
- landslide
- drought
- forest fire
- extreme weather
- historical losses
- vulnerability
- exposure
- response capacity

### Q. Education

- schools
- universities
- students
- teachers
- participation rates
- literacy where available
- quality proxies

### R. Health

- hospitals
- puskesmas
- health workers
- service access
- disease/health indicators
- maternal/child health

### S. Social

- poverty
- unemployment
- social protection
- inequality
- vulnerable populations
- conflict/complaint indicators where responsibly sourced

### T. Digitalization / technology

- internet penetration
- broadband
- BTS/coverage
- digital public services
- technology capacity proxies

## Data resolution hierarchy

Every dataset must explicitly state:

- national
- island/region
- province
- regency/city
- district/subdistrict
- village/settlement
- point/asset

Never silently promote lower-resolution data into a higher-resolution field.

## Temporal rules

Different domains can have different latest years. Preserve actual reference years.

Example:

```text
Population → 2025
PDRB → 2025
APBD → 2026
Mineral → latest published baseline
Forest → latest published baseline
Geometry → latest official boundary snapshot
```

The game should label the overall snapshot and each underlying reference period.

## Raw/processed separation

```text
raw
  ↓
processed
  ↓
normalized
  ↓
game model
```

Never edit raw source captures in place.

## Gap registry

For every important field with incomplete coverage, record:

- requested field
- target geography
- source searched
- search date
- why unavailable
- alternate source used, if any
- resolution mismatch
- confidence
