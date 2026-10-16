# 08 MAP AND GIS SPECIFICATION

## Goal

Use real Indonesian administrative geography as the basis of the game map.

## Source preference

Primary geographic source should be the most current official BIG or equivalent government boundary dataset available during the research snapshot.

## Map requirements

- full Indonesia coverage
- panning
- zooming
- selection by click/tap
- province selection
- regency/city selection
- visually distinguish selected region
- show region-level panel

## Geographic IDs

Use authoritative region codes as primary keys when available. Names are display labels, not stable IDs.

Maintain crosswalks when different agencies use different codes.

## Geometry handling

Do not modify raw official geometry.

Derived geometry may be simplified for game performance but must:

- preserve topology sufficiently for selection
- retain source reference
- record simplification settings
- preserve a path back to the raw geometry

## Performance strategy

Possible approaches:

- simplified render geometry
- separate high-resolution inspection geometry
- tile/layer loading for visuals
- indexed polygon hit testing
- vector-to-texture preprocessing where appropriate

The simulation state must remain independent of the map rendering layer.

## Region hierarchy

```text
Indonesia
↓
Island/region grouping for navigation and visual framing
↓
Province
↓
Regency/City
```

Island labels are an organizational/game layer and must not overwrite official administrative hierarchy.

## Realism rule

Do not alter boundaries to create gameplay convenience unless explicitly documented as a visual abstraction. Administrative identity must remain accurate.

## Deep-data behavior

Clicking a region should be able to reveal:

- real baseline values
- current simulated values
- resource profile
- cultural profile
- sentiment
- active policies
- active events
- source metadata

## Map visual style

Top-down 2D strategy map with clear readable borders and modern UI, not a photorealistic satellite map.

The visual style should borrow the readability of strategy games while preserving real geography.
