# 16 RESEARCH EXECUTION PLAN

## Operating model

**ChatGPT = Research Lead / Design Reviewer**  
**Claude Code = Data Engineer / Scraper / Automation Agent**

## Phase R0: Research inventory

Create a dataset/source matrix containing:

- domain
- dataset
- variable
- definition
- target geography
- target temporal coverage
- primary source
- alternate source
- access method
- frequency/update cadence
- usage in game
- priority

## Phase R1: Source registry

For each official institution, discover:

- official portal
- API
- downloadable files
- GIS service
- publication archive
- dataset catalog

Store source cards under `research/sources/`.

## Phase R2: Geography first

Get authoritative codes and boundaries before joining other datasets.

## Phase R3: Data ingestion

For each dataset:

1. download
2. cache raw
3. checksum
4. extract
5. normalize
6. validate
7. map geography keys
8. store provenance
9. report coverage

## Phase R4: Cultural ingestion

Build a broad cultural index before deciding which cultural objects become mechanics.

## Phase R5: Case discovery

Search systematically across decades and regions. Maintain a candidate list, then validate.

## Phase R6: Cross-domain joins

Join:

- geography + demography
- geography + economy
- geography + resources
- geography + culture
- geography + disasters
- geography + cases

## Phase R7: Data snapshot

Freeze a competition research snapshot with:

- snapshot ID
- collection date
- source versions
- source URLs
- data years
- transformation code version

## Phase R8: Game translation

Only after factual data are stable, create:

- normalized game variables
- formulas
- thresholds
- event triggers
- causal relationships

## Research report standard

Every major research phase outputs:

- coverage summary
- source summary
- top data quality issues
- unresolved gaps
- known contradictions
- next steps
