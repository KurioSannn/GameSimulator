# Geo region crosswalk validation

Generated: 2026-10-22T02:12:26+00:00

- Provinsi: **38** (expected 38 per Kepmendagri 2025)
- Kabupaten: **416** (expected 416)
- Kota: **98** (expected 98)
- BIG features excluded (no valid single kab/kota code; disputed/uncoded areas): **28**
- Kab/kota represented by multiple BIG polygons rows: ['74.03', '74.04', '74.07', '74.10', '74.13']

## Issues

- 12.77: name differs BIG='Kota Padang Sidempuan' secondary='Kota Padangsidimpuan'
- 16.02: name differs BIG='Ogan Komering Ilir' secondary='Kabupaten Ogan Komering'
- 31.01: name differs BIG='Adm. Kep. Seribu' secondary='Kabupaten Administrasi Kepulauan Seribu'

## Excluded BIG features

| objectid | namobj | kdpkab | tipadm | remark |
|---|---|---|---|---|
| 65 | Maluku |   | 999 |  |
| 66 | Maluku |   | 999 |  |
| 67 | Maluku |   | 999 |  |
| 68 | Maluku |   | 999 |  |
| 69 | Maluku |   | 999 |  |
| 70 | Maluku |   | 999 |  |
| 74 | Maluku Utara |   | 999 | Pulau Bermasalah |
| 75 | Maluku Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Maluku Utara |
| 84 | Minahasa Selatan/Bolaang Mongondwo Timur | 71.05/71.10 | 999 | Danau Moat, area bermasalah |
| 76 | Maluku Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Maluku Utara |
| 77 | Maluku Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Maluku Utara |
| 105 | Sulawesi Selatan |   | 6 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sulawesi Selatan |
| 161 | Kepulauan Riau |  | 4 | None |
| 258 | Sumatera Barat |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Barat |
| 257 | Sumatera Barat |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Barat |
| 259 | Sumatera Barat |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Barat |
| 260 | Sumatera Barat |   | 999 | Tidak ada titik pulau di gazeter 2021 |
| 261 | Sumatera Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Utara |
| 262 | Sumatera Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Utara |
| 263 | Sumatera Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Utara |
| 264 | Sumatera Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Utara |
| 265 | Sumatera Utara |   | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Sumatera Utara |
| 315 | Jawa Timur | None | 6 |   |
| 316 | Jawa Timur |   | 6 | Berdasarkan Berita Acara Verifikasi tahun 2008 Pulau Galang merupakan kewenangan Provinsi Jawa Timur |
| 451 | Kalimantan Barat |  | 999 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Kalimantan Barat |
| 452 | Kalimantan Timur | None | 6 | Berdasarkan Kepmendagri 050-145 Tahun 2022, masuk ke Kalimantan Timur |
| 547 | Indonesia |  | 4 | None |
| 548 | Indonesia |  | 4 | None |

Excluded areas are kept in raw data and are rendered as neutral, non-selectable map areas (disputed/unassigned); they are never assigned to a region by this pipeline.
