# AREA UNIT INVESTIGATION: BIG `LUASWH` and `Shape_Area` (GAP-0004)

- **Snapshot:** `SNAP-2026-10-21`
- **Investigated:** 2026-10-21/22
- **Scripts:** `scripts/pipelines/geo/v2/audit_area_units.py`, `scripts/pipelines/geo/v2/fetch_bps_area_tables.py`
- **Data:**
  - `data/processed/geography/SNAP-2026-10-21/area_unit_audit.csv`: all 514 regions
  - `research/reports/area_unit_audit_summary.json`: statistics and the pre-declared sample

## Conclusion

| Field | Published label / declared unit | Finding | Status |
|---|---|---|---|
| `LUASWH` | "Luas Wilayah Menurut Peraturan (HA)" | Values are **km²**, not hectares. Semantically it is the **legal/regulated area**: the same figure that BPS reprints from Kepmendagri 300.2.2-2138/2025. | `UNIT_KM2_EVIDENCED`: the declared "HA" contradicts the data; publisher confirmation is still outstanding |
| `Shape_Area` | "SHAPE_Area" (no unit) | **Planar square degrees** in EPSG:4326 (an ArcGIS geometry property). It is not a physical area and must never be used as km². | `SEMANTICS_VERIFIED` |
| `geom_area_km2` | n/a (derived by NUSANTARA) | WGS84 ellipsoidal area of the raw polygon, kept in its own column | `DERIVED` |

**Nothing has been converted.** The registry keeps `big_luaswh_raw` exactly as published, and the audit keeps the original label and declared unit next to the evidence (tests: `TestNoSilentAreaConversion`). Render geometry carries no area fields at all. Any game-facing "luas wilayah" must later be chosen deliberately and labelled with its source and unit. This investigation does not change any administrative code or polygon identity.

## Method

1. **`LUASWH` vs geometry.** For each region's main BIG polygon, the area is computed on the WGS84 ellipsoid. The coordinates are projected into the ellipsoidal Lambert cylindrical equal-area projection (x = a·λ, y = a·q(φ)/2, Snyder 1987), which preserves area exactly on the ellipsoid, and then measured with the shoelace formula. The implementation is tested against an independent numerical integral of the ellipsoidal area element (agreement within 1e-9; `tests/test_geo.py`). The working hypothesis was: if `LUASWH` is in hectares, `LUASWH / geom_km2 ≈ 100`; if km², it is ≈ 1.
2. **`LUASWH` vs independent official figures.** BPS province tables "Luas Daerah dan Jumlah Pulau Menurut Kabupaten/Kota" (SRC-0008) give "Luas Wilayah" in km² and name their source decree. 2025 tables were used where available, otherwise 2024.
3. **`Shape_Area` semantics.** `Shape_Area` was compared with a planar shoelace area computed directly on the raw degree coordinates.

## Results (all 514 regions)

| Comparison | n | Median ratio | Within 1 % | ≈100× (hectare hypothesis) |
|---|---|---|---|---|
| `LUASWH` / geometry km² | 514 | 0.99999999995 | 505 | **0** |
| `LUASWH` / BPS km² (all tables) | 430 | 0.9999999 | 426 | **0** |
| `LUASWH` / BPS km² (tables citing 300.2.2-2138/2025) | 228 | 0.9999999 | 226 | **0** |
| `Shape_Area` / planar deg² | 514 | 1.0000000 | 514 (max deviation 4e-7) | n/a |

In addition, 367 regions match BPS to two decimals exactly.

BPS coverage: 447 of 514 regions have a BPS figure. 17 of them were excluded from the ratios (see the source anomaly below). There is no BPS table for Aceh, Maluku, Papua Barat, Papua Selatan, Papua Tengah, Papua Pegunungan, or Papua Barat Daya (GAP-0011).

### Pre-declared varied sample

The sample covers small cities, large regencies, tiny-island regions, and all seven navigation groups.

| ID | Region | `LUASWH` (raw) | `Shape_Area` (raw, deg²) | Geometry km² (derived) | BPS km² (table year) | BPS flag | `LUASWH`/geometry |
|---|---|---|---|---|---|---|---|
| 12.73 | Kota Sibolga | 12.65 | 0.00103 | 12.65 | 11.47 (2024) | OK | 1.0000 |
| 13.75 | Kota Bukittinggi | 24.17 | 0.00196 | 24.17 | 24.17 (2025) | OK | 1.0000 |
| 31.01 | Kab. Adm. Kepulauan Seribu | 10.95 | 0.00089 | 10.92 | 10.73 (2024) | OK | 1.0030 |
| 32.01 | Kab. Bogor | 2,991.78 | 0.24461 | 2,991.78 | 2,991.78 (2025) | OK | 1.0000 |
| 33.71 | Kota Magelang | 18.56 | 0.00152 | 18.56 | 18.56 (2025) | OK | 1.0000 |
| 35.76 | Kota Mojokerto | 20.48 | 0.00168 | 20.48 | 20.48 (2025) | OK | 1.0000 |
| 35.78 | Kota Surabaya | 338.05 | 0.02775 | 338.87 | 338.05 (2025) | OK | 0.9976 |
| 51.08 | Kab. Buleleng | 1,322.12 | 0.10850 | 1,322.23 | 1,322.12 (2025) | OK | 0.9999 |
| 53.11 | Kab. Sumba Timur | 6,975.20 | 0.57507 | 6,976.33 | 6,975.20 (2025) | OK | 0.9998 |
| 61.06 | Kab. Kapuas Hulu | 31,318.25 | 2.54463 | 31,318.26 | 31,318.25 (2025) | OK | 1.0000 |
| 65.02 | Kab. Malinau | 38,901.82 | 3.16361 | 38,901.45 | 32,902.00 (2025) | OK | 1.0000 |
| 73.71 | Kota Makassar | 177.17 | 0.01445 | 177.17 | 177.17 (2025) | OK | 1.0000 |
| 74.07 | Kab. Wakatobi | 450.80 | 0.03678 | 450.62 | 450,800.00 (2025) | THOUSANDFOLD_SUSPECTED | 1.0004 |
| 81.01 | Kab. Maluku Tengah | 8,253.42 | 0.67152 | 8,253.26 | no table | n/a | 1.0000 |
| 82.02 | Kab. Halmahera Tengah | 2,272.26 | 0.18508 | 2,278.08 | 2,272.26 (2025) | OK | 0.9974 |
| 93.01 | Kab. Merauke | 45,016.45 | 3.69003 | 45,007.41 | no table | n/a | 1.0002 |
| 94.04 | Kab. Mimika | 18,309.72 | 1.49162 | 18,304.71 | no table | n/a | 1.0003 |

## Why legal/regulated area and polygon area can differ

- **Different geometry versions.** The legal figure is fixed by decree (here Kepmendagri 2025) and computed from the boundary version in force at that time. BIG revises segments afterwards: 350 of the 541 features carry a June 2026 update stamp. All 9 regions where `LUASWH` and geometry disagree by more than 1 % have polygons revised in edition 20260612, while `LUASWH` still equals the 2025 decree figure:
  - Tanjung Jabung Barat (+10.4 %) and Tanjung Jabung Timur (−10.3 %): a boundary moved between the two neighbours.
  - Sukamara, Semarang, Pekalongan, Tojo Una-Una, Morowali Utara and Kepulauan Selayar: between 1 % and 4.5 %.
  - Halmahera Utara is the exception (below).
- **Older decrees.** BPS 2024 tables cite Kepmendagri 100.1.1-6117/2022, so Sibolga (11.47 vs 12.65) and Kepulauan Seribu (10.73 vs 10.95) reflect legal revisions between decrees.
- **Measurement basis.** A legal area may be computed on a different datum, projection or ellipsoid, or may include or exclude inland water and floating ("terapung") areas. Kepulauan Seribu differs by 0.3 % even though its edition is current.
- **Disputed or indicative boundaries.** Malinau's BPS table cites a BIG letter instead of the decree (32,902 vs 38,901.8 km²).

## Source anomalies (recorded, not corrected)

1. **BPS Sulawesi Tenggara 2025.** All 17 kab/kota values are about 1,000× the km² figure (for example Kolaka "2.958.870,00 km²" against 2,958.87). This looks like a decimal separator misplaced at the source. The rows are flagged `THOUSANDFOLD_SUSPECTED`, excluded from the ratios, and the raw value is kept.
2. **Halmahera Utara (82.03).** `LUASWH` is 2,237.39, while geometry gives 3,402.0 and the BPS 2025 figure is 3,402.94. Here the geometry agrees with the legal figure and `LUASWH` does not, which makes it the only case where `LUASWH` is inconsistent with both. Cause unknown. It stays raw and is listed in GAP-0004.
3. **Label error.** The BIG field alias "(HA)" contradicts the data, which is in km².

## Evidence assessment

The km² conclusion rests on three independent lines of evidence: polygon geometry (514 regions), official BPS/Kemendagri tables (430 regions), and the complete absence of any 100× relationship. The unit is therefore treated as evidenced, not assumed. GAP-0004 stays open at low severity because BIG has not itself corrected or confirmed the alias.

## Source references

- **BIG `LUASWH`, `Shape_Area`, geometry.** SRC-0001, https://geoservices.big.go.id/rbi/rest/services/BATASWILAYAH/BATAS_KABKOTA_AR/MapServer/0 (edisi Juni 2026). The field alias "Luas Wilayah Menurut Peraturan (HA)" comes from the layer's `fields` metadata (`data/raw/SRC-0001/SNAP-2026-10-21/kabkota_service.json`).
- **Per-region comparison.** `data/processed/geography/SNAP-2026-10-21/area_unit_audit.csv` keeps the declared label and unit (`luaswh_source_label`, `luaswh_declared_unit` = HA) separate from the evidenced interpretation (`luaswh_evidenced_unit` = km2, `luaswh_unit_status` = UNIT_KM2_EVIDENCED). The derived `geom_area_km2` sits in its own column, with its method in `geom_area_method`. Each BPS figure carries its table year, `bps_sumber` and `bps_url`.
- **BPS provincial area tables** (SRC-0008, retrieved 2026-10-21; raw HTML in `data/raw/SRC-0008/SNAP-2026-10-21/`):

| Table (subdomain) | Data year | Source cited by BPS (`sumber`, truncated) | URL |
|---|---|---|---|
| aceh | n/a | parse_failed | https://aceh.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2024 |
| sumut | 2024 | *) Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 100.1.1-6117 Tahun 2022 tanggal 9 November 20 | https://sumut.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2024 |
| jakarta | 2024 | Kementerian Dalam Negeri/ Ministry of Home Affairs | https://jakarta.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2024 |
| maluku | n/a | parse_failed | https://maluku.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2024 |
| papuabarat | n/a | parse_failed | https://papuabarat.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2024 |
| aceh | n/a | parse_failed | https://aceh.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sumut | n/a | parse_failed | https://sumut.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sumbar | 2025 | Kementerian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 Tanggal 25 April 2025 T | https://sumbar.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| riau | 2025 | Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025, 25 April 2025 Tentang Pemberian dan Pemutakhiran | https://riau.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jambi | 2025 | Kementerian Dalam Negeri/Ministry of Home Affairs | https://jambi.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sumsel | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025/Ministry of Home Affairs | https://sumsel.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| bengkulu | 2025 | - Kementerian Dalam Negeri / Ministry of Home Affairs - Badan Pertanahan Nasional Kantor Wilayah Bengkulu/ Nat | https://bengkulu.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| lampung | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 050-145 Tahun 2022 tanggal 14 Februari 2022/ Min | https://lampung.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| babel | 2025 | Biro Pemerintahan Sekretariat Daerah Provinsi Kepulauan Bangka Belitung / Government Bureau of Kepulauan Bangk | https://babel.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kepri | 2025 | Biro Pemerintahan dan Otonomi Daerah Provinsi Kepulauan Riau/ Government Bureau and Regional Outonomy of Kepul | https://kepri.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jakarta | n/a | parse_failed | https://jakarta.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jabar | 2025 | Kementerian Dalam Negeri/ Ministry of Home Affairs jdih.kemendagri.go.id/dokumen/view?id&#x3D;1937&amp;utm dia | https://jabar.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jateng | 2025 | Berdasarkan Peraturan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/Based on Minist | https://jateng.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jogja | n/a | fetch_failed | https://jogja.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| jatim | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 100.1.1-6117 Tahun 2022 tanggal 9 November 2022/ | https://jatim.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| banten | 2025 | Kementerian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025/ Ministry of Home Affai | https://banten.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| bali | 2025 | Kementerian Dalam Negeri/Ministry of Home Afairs | https://bali.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| ntb | 2025 | Keputusan Menteri Dalam Negeri Nomor 100.1.1-6117 Tahun 2022 Decree of the Minister of Home Affairs Number 100 | https://ntb.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| ntt | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/Mi | https://ntt.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kalbar | 2025 | Kementerian Dalam Negeri/Ministry of Home Affairs | https://kalbar.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kalteng | 2025 | Berdasarkan Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tentang Pemberian dan Pemutakhiran Ko | https://kalteng.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kalsel | 2025 | Kementerian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2–2138 Tahun 2025 tanggal 25 April 2025 t | https://kalsel.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kaltim | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025/ Ministry of Home Affair | https://kaltim.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| kaltara | 2025 | Badan Informasi Geospasial berdasarkan Surat Deputi Bidang Informasi Geospasial Dasar Nomor B-16.10/DIGD-BIG/I | https://kaltara.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sulut | 2025 | Sumber/Source: Kementerian Dalam Negeri/Ministry of Home Affairs | https://sulut.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sulteng | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025 | https://sulteng.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sulsel | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/ M | https://sulsel.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sultra | 2025 | Kementerian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/M | https://sultra.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| gorontalo | 2025 | Kementerian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/  | https://gorontalo.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| sulbar | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025 Te | https://sulbar.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| maluku | n/a | parse_failed | https://maluku.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| malut | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April 2025/Mi | https://malut.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| papuabarat | n/a | parse_failed | https://papuabarat.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| papua | 2025 | Sumber: Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2-2138 Tahun 2025 tanggal 25 April | https://papua.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
| yogyakarta | 2025 | Kementrian Dalam Negeri, Keputusan Menteri Dalam Negeri Nomor 300.2.2–2138 Tahun 2025 tanggal 25 April 2025/ M | https://yogyakarta.bps.go.id/id/statistics-table/3/VUZwV01tSlpPVlpsWlRKbmMxcFhhSGhEVjFoUFFUMDkjMw==/luas-daerah-dan-jumlah-pulau.html?year=2025 |
