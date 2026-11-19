# Execution Report: Official Indonesian Road Network Ingestion & Map Integration

- **Date**: 2026-11-20
- **Pipelines**: `scripts/pipelines/game/fetch_indonesia_roads.py`, `scripts/pipelines/game/build_indonesia_roads.py`
- **Source Registry IDs**: `SRC-PUPR-JALAN-NASIONAL`, `SRC-PUPR-BPJT-TOL-OPERASI`

## Attempted
1. Probed official geospatial endpoints from Badan Informasi Geospasial (`geoservices.big.go.id`) and Kementerian Pekerjaan Umum (`sigi.pu.go.id`).
2. Queried public ArcGIS REST FeatureServer endpoints under `sigi.pu.go.id/serverpu/rest/services/Hosted/`.
3. Archived raw WGS84 (`EPSG:4326`) GeoJSONs with provenance manifest and SHA-256 checksums, simplified polylines into compact offline game binary assets, and rendered on both 3D (`DioramaRoads`) and 2D (`MapView`) map views.

## Succeeded
- **`SRC-PUPR-JALAN-NASIONAL`** (`Hosted/ast_bm_jalan_nasional_iri/FeatureServer/0`, last edit `2025-06-24`): Retrieved all **3,184** national road features (`3,190,095` raw vertices, `122.57 MB`), spanning `lon [95.22°, 141.00°]` and `lat [-10.73°, +5.91°]`. Derived offline into **3,176** simplified polylines (`47,576` vertices, ~`45,119 km`, RDP tolerance `0.11` wu).
- **`SRC-PUPR-BPJT-TOL-OPERASI`** (`Hosted/ast_bpjt_tol_operasi_v2/FeatureServer/0`, last edit `2025-06-19`): Retrieved all **146** operational toll road features (`77,786` raw vertices, `3.00 MB`), spanning `lon [95.39°, 125.20°]` and `lat [-8.79°, +5.61°]`. Derived offline into **168** simplified polylines (`3,925` vertices, ~`5,452 km`, RDP tolerance `0.05` wu).
- Packaged combined binary `game/data/map/art/indonesia_roads.bin` (`428.5 KB`) + `indonesia_roads.json` with zero runtime network requests.

## Failed / Skipped
- `geoservices.big.go.id/arcgis/rest/services/PTRA/Atlas_Transportasi_Darat/MapServer` and `TRANSPORTASI`: SSL handshake timeout during probe.
- `sigi.pu.go.id/serverpu/rest/services/sigi_postgis/*` and `IGTPUPR`: HTTP 499 Token Required; respected access control and skipped without bypass.
- `sigi.pu.go.id/serverpu/rest/services/Jalan_Provinsi/MapServer`: Covered North Sumatra province only (`317` features); skipped to preserve national uniformity across all 38 provinces.
- `overpass-api.de/api/status`: Timed out during probe; unnecessary once official Kementerian PU datasets succeeded.

## Coverage & Known Gaps
- Full national coverage across Sumatra, Java, Bali, NTB, NTT, Kalimantan, Sulawesi, Maluku, and Papua for official National Roads and Operational Toll Roads.
- Provincial (`Jalan Provinsi`) and district/local (`Jalan Kabupaten/Kota`) roads are not yet packaged uniformly nationwide; urban local road props continue dressing cities inside `diorama.json`.

## Next Action
- Maintain `data/raw/pupr_roads/MANIFEST.json` and `game/data/map/art/indonesia_roads.{json,bin}` under automated test verification (`test_diorama.gd`, `validate_all.py`, `--qa-diorama`).
