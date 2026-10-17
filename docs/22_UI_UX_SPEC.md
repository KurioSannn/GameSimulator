# 22 UI/UX SPECIFICATION

## Language

All user-facing game text must be **Bahasa Indonesia**.

## Platform priority

**Primary:** Windows desktop `.exe`.

The UI is intentionally designed as a desktop strategy/simulation interface. Do not design mobile-first.

### Recommended design baseline

Claude Code may adjust these after inspecting the project, but start with a desktop reference canvas such as **1920×1080 (16:9)** and verify usability at common 16:9 sizes. The UI must tolerate reasonable window resizing without breaking critical content.

## Interaction model

Primary: mouse and keyboard.

Expected interactions:

- left click: select/confirm
- right click: contextual close/cancel where justified
- mouse wheel: map zoom / list scrolling depending on focus
- middle-button drag or right-button drag: map panning if ergonomic
- hover: tooltips/data previews
- keyboard shortcuts: optional for frequent actions
- Escape: close modal/panel or pause flow

Do not add touch-specific layout requirements to the desktop UI.

## Main screen hierarchy

```text
National status
↓
Current case / priority
↓
Key actions
↓
Map / regions
↓
Secondary information
```

## Information hierarchy

### Level 1: Ringkas

- Anggaran
- Ekonomi
- Kesejahteraan
- Kepercayaan
- Stabilitas
- Lingkungan

### Level 2: Wilayah

- regional economy
- population
- resources
- infrastructure
- sentiment
- active policies
- active cases

### Level 3: Data mendalam

- raw/official values
- units
- reference year
- source institution
- source link/reference
- methodology note

## Map UX

Map is a core gameplay surface, not background decoration.

Required desktop behavior:

1. pan across Indonesia
2. zoom national → province → regency/city
3. hover a region to preview basic state
4. click a region to open regional details
5. visually indicate current case-affected regions
6. support thematic overlays such as Economy, Food, Energy, Environment, Sentiment, or Infrastructure
7. maintain readable labels at appropriate zoom levels

The map must remain responsive even when every region is being simulated. Rendering and simulation state are separate concerns.

## Regional panel

A region panel clearly separates:

- baseline real data
- current simulated state
- cultural profile
- current sentiment
- active policies/effects
- current cases/risk

## Value formatting

Data layer preserves actual values and units. UI may abbreviate values for readability.

Example:

```text
Data layer:
Rp 3.153.580.000.000.000

UI:
Rp 3,15 kuadriliun
```

Never discard precision from the data layer merely because the UI displays an abbreviated value.

## Sentiment explanation

When sentiment changes substantially, expose major drivers.

Example:

> Sentimen turun terutama karena kenaikan harga pangan dan lambatnya pemulihan infrastruktur.

## Data/source UX

Provide a clear path from an in-game value to its provenance where practical. A dedicated **Pusat Data** screen should expose source institution, reference year, units, and data snapshot information.

## Accessibility

- readable typography
- clear contrast
- no color-only meaning
- concise copy
- visible focus/selection state
- tooltips for unfamiliar indicators

## UI personality

Modern strategy simulation, not a government website. Information-dense but visually calm, polished, and intentionally desktop-oriented.

## Android adaptation later

If an APK is required by the competition, adapt the finished desktop information model rather than redesigning the entire game. Identify only the minimum changes necessary for touch input, smaller screens, and performance constraints.
