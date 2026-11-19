# Low-poly diorama props

Creator: Kenney. License: CC0-1.0, verified against the creator's four pack pages.

- https://kenney.nl/assets/nature-kit
- https://kenney.nl/assets/city-kit-suburban
- https://kenney.nl/assets/city-kit-commercial
- https://kenney.nl/assets/city-kit-roads

The official Nature/Suburban ZIP endpoints returned HTTP 403 during the initial remake. These 48 models were obtained from the public CC0 conversion mirror https://github.com/Hidencod/tge-assets, pinned to commit 01e09f8f034c6abf1254cd4cd35aaa60ce310b31. The mirror's redistribution notice is preserved in LICENSE.txt. Each GLB has a source URL, retrieval metadata and SHA-256 in manifest.json.

The shared catalog at game/data/map/art_catalog.json defines 18 nature models, 12 houses, 12 commercial buildings/towers, four road tiles and two streetlights. Download, placement and runtime consume this same catalog. Total GLB size: 3,468,000 bytes.

The game constrains both height and footprint, adjusts nature and house-roof colors through its own shaders, batches repeated geometry using Godot MultiMesh, and adds foliage sway and subtle window glints. Original building palette textures remain in the GLBs. Source model files are unchanged.

These are decorative miniature props, not measured vegetation, buildings, infrastructure, elevation, or settlement boundaries. A decorative core is fitted inside each of 514 canonical regions; surrounding blocks fit only where the polygon allows. Their center, corners and edge midpoints are validated. These miniatures do not locate actual individual buildings or roads. Analytical indicator layers hide them.

Re-fetch: python scripts/pipelines/game/fetch_map_art.py
Rebuild coast field and placement data: python scripts/pipelines/game/build_map_art.py

All runtime resources are local. Python/SciPy and internet access are used only for asset preparation.
