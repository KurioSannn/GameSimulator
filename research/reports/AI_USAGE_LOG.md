# AI USAGE LOG

Format per docs/12_AI_USAGE_AND_PROVENANCE.md.

| date | tool | purpose | input type | output type | human modification | final usage | license/terms checked | evidence path |
|---|---|---|---|---|---|---|---|---|
| 2026-10-21 | Claude Code (Claude Opus 5.5) | Research bootstrap: discover official geography sources, write capture/normalize/validate scripts, write source/dataset cards and report | Project docs; public official web services (BIG, BPS, Kemendagri) | Python scripts, CSV/JSON data, YAML cards, Markdown report | Pending team review | Research data layer (not yet in game) | Source terms recorded per source card; BIG formal reuse terms PENDING | research/reports/RESEARCH_BOOTSTRAP_REPORT.md |
| 2026-10-21/22 | Claude Code (Claude Opus 5.5) | Geography milestone: complete BIG raw capture; area-unit investigation; mapshaper LOD pipeline (two-pass, Douglas-Peucker); validation, island audit, province cross-check, previews, load timing; navigation groups file from team-specified grouping | Public official services (BIG, BPS), team instructions | Python scripts, GeoJSON LODs, JSON/CSV/Markdown reports, YAML cards | Team approved approach provisionally; tolerance rule and method changes documented for review | Research data layer and map geometry (not yet in game) | BIG reuse terms PENDING (SRC-0001) | research/reports/GEOMETRY_VALIDATION_REPORT.md |
