# 13 ASSET PIPELINE

## Team

- Ananda: character/visual design
- Cleo: UI/asset/environment design
- Galih: integration and technical implementation

## Design workflow

```text
Figma / GPT-assisted ideation
        ↓
approved visual direction
        ↓
final vector/bitmap asset
        ↓
export
        ↓
Godot import
        ↓
integration
```

## Preferred formats

- SVG for scalable vector assets
- PNG where raster is required
- OGG/WAV/other appropriate formats depending on Godot/audio needs

## SVG use cases

- UI icons
- buttons
- cards
- symbols
- simple character assets
- map overlays
- decorative elements

## Naming convention

Use predictable names such as:

```text
ui_btn_primary.svg
icon_food.svg
char_nara_neutral.svg
region_java_map.svg
```

Exact convention can be refined, but consistency is mandatory.

## Asset integration contract

Every asset handoff should include:

- filename
- format
- dimensions/viewbox
- transparency
- intended use
- scene/UI location
- author/tool
- provenance/license

## Visual direction

- 2D, desktop-first
- clean vector/editorial aesthetic
- readable strategy-game UI
- moderate palette
- clear typography
- low unnecessary clutter
- no fake photorealism
- visuals should support usability first

## Character expression baseline

Target reusable Nara expressions:

- netral
- berpikir
- khawatir
- percaya diri
- terkejut
- frustrasi
- lega
- kecewa
- serius
- senang

## Audio

Use generated music/voice only with documented tool usage and licensing/usage checks.
