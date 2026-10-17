# RESEARCH BOOTSTRAP PROMPT

Use this when the team wants Claude Code to begin the research/data phase before game feature development.

## Task

Bootstrap the NUSANTARA research pipeline.

### Objectives

1. Inspect all project docs.
2. Establish the source registry.
3. Establish the dataset inventory.
4. Discover official APIs/files/GIS services.
5. Establish the current administrative geography baseline.
6. Build the first source and dataset cards.
7. Implement raw-data caching and provenance.
8. Produce a research coverage report.
9. Do not fabricate missing fields.
10. Do not start large gameplay coding.

### Required outputs

- `research/sources/` source cards
- `data/catalog/` dataset cards
- `data/schemas/` machine-readable schemas where practical
- `research/reports/RESEARCH_BOOTSTRAP_REPORT.md`
- source access log
- gap registry
- reproducibility notes

### First data milestone

Establish:

- official region codes
- province registry
- regency/city registry
- official current boundary source
- geography crosswalk
- current data snapshot metadata

Only after that should large-scale domain ingestion begin.
