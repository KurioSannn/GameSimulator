# Remake peta low-poly NUSANTARA — 19 November 2026

Otorisasi: pengguna meminta remake peta low-poly dengan kualitas visual lebih baik dan riset aset/library di luar proyek, termasuk GitHub. Pelaksana: ChatGPT/Codex. Keputusan: D-080.

## Yang dikerjakan dan berhasil

- Membandingkan referensi Figma, renderer yang ada, aset Kenney/Quaternius, repositori GodotOceanWaves/HTerrain, dokumentasi MultiMesh dan SciPy.
- Memilih delapan GLB Kenney berlisensi CC0: dua pohon, dua palem, dua batu, dua rumah. Lisensi dikonfirmasi pada halaman pembuat; model dari mirror konversi GitHub dipatok pada commit 01e09f8f034c6abf1254cd4cd35aaa60ce310b31.
- Mengemas sumber, lisensi, checksum dan versi dalam game/assets/map/kenney/. Warna alam disesuaikan melalui material runtime, tanpa mengubah GLB asal.
- Membangun 2298 anchor dekoratif: 1849 pohon, 206 palem, 145 batu dan 98 simbol kota. Semuanya diperiksa berada dalam polygon wilayah kanoniknya. Simbol kota tidak mengklaim titik gedung atau luas permukiman aktual.
- Menampilkan dekorasi lewat delapan MultiMesh batch. Sepuluh gugus awan memakai satu batch terpisah. Tidak ada node simulasi atau scene untuk setiap entitas data.
- Merombak warna darat/laut, facet permukaan, perairan pesisir, buih pantai, tepi pulau, framing kamera, label kawasan, respons hover/pilih dan penanda kasus aktif.
- Pohon, air, awan dan penanda memiliki gerakan ringan yang terpisah dari tick simulasi. Preferensi kurangi gerakan membekukan gerakan ambient dan memotong transisi seleksi.
- Peta 3D menjadi tampilan normal saat mulai; mode 2D tetap tersedia lewat T. Lapisan Bentang Nusantara menampilkan diorama. Lapisan indikator menampilkan nilai simulasi dengan dekorasi disembunyikan.
- Menyesuaikan menu lapisan agar pilihan programatik dan tampilan aktual selalu sama.

## Riset dan alasan pemilihan

| Sumber | Hasil |
| --- | --- |
| [Kenney Nature Kit](https://kenney.nl/assets/nature-kit) | CC0, bentuk sederhana cocok pada skala nasional dan ringan untuk instancing. |
| [Kenney City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban) | CC0; dua simbol bangunan generik dipakai sebagai dekorasi kota. |
| [Mirror tge-assets](https://github.com/Hidencod/tge-assets) | Konversi GLB dengan texture embedded dan pemberitahuan CC0. Delapan file dipatok ke commit dan diverifikasi SHA-256. Tidak menjalankan kode repositori. |
| [Quaternius Ultimate Nature](https://quaternius.com/packs/ultimatenature.html) | Alternatif CC0 ditinjau; tidak dibundel agar satu keluarga bentuk/palet konsisten. |
| [GodotOceanWaves](https://github.com/2Retr0/GodotOceanWaves) | FFT ocean/MIT ditinjau; tidak diintegrasikan. Shader pesisir sederhana lebih sesuai dengan kamera strategi dan renderer Compatibility yang ada. |
| [HTerrain](https://github.com/Zylann/godot_heightmap_plugin) | Ditinjau sebagai alternatif; tidak diintegrasikan karena tidak perlu mengganti polygon/LOD/hit testing geografi yang sudah tervalidasi. |
| [SciPy distance transform](https://docs.scipy.org/doc/scipy/reference/generated/scipy.ndimage.distance_transform_edt.html) | Dipakai pada build untuk menghitung jarak ke garis pantai dari rasterisasi triangulasi asli. |
| [Godot MultiMesh](https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html) | API engine yang sudah tersedia dipakai untuk batching prop, tanpa dependency runtime tambahan. |

Catatan lengkap, status akses dan metadata sumber: [katalog riset visual](../sources/map_visual_research_2026-11-19.json).

## Geografi dan data

- Mesh GIS LOD1/2/3, urutan/kode wilayah, semua 514 state simulasi, parameter, input RNG, raw data dan format save tidak diubah.
- Peta display masih memakai seluruh geometri kanonik. Field pesisir adalah efek visual raster, bukan pengganti polygon atau hit testing.
- Relief batu, vegetasi, rumah dan efek air adalah **dekorasi artistik**, bukan hasil pengukuran elevasi, tutupan lahan, luas kota atau batimetri. Penjelasan terlihat pada legenda lapisan.
- Semua anchor prop disampel di dalam triangle asli memakai NumPy RNG dengan seed khusus 20261119, terpisah dari RNG simulasi.
- JSON hasil build menyimpan SHA-256 mesh sumber, seed, versi dependency, dimensi dan kontrak channel field.
- Tidak ada request jaringan dalam runtime baru. Python dan internet digunakan hanya untuk persiapan aset.

## Reproduksi

Jalankan dari root repository:

    python scripts/pipelines/game/fetch_map_art.py
    python scripts/pipelines/game/build_map_art.py

Dependency build dipatok di scripts/pipelines/game/map_art_requirements.txt. Paket model tetap di game/assets/map/kenney; field dan anchor dekorasi di game/data/map/art.

Build ulang menghasilkan JSON dengan SHA-256 identik:

    b01e70fcefc7ebab6049d788395fa66dfd642d9b88e5765f101f657fbc0ed21c

## Verifikasi

- **151/151 tes headless lulus**, termasuk kasus/golden master, determinisme, save/load, geografi, kompilasi seluruh skrip, adapter wilayah dan tiga tes diorama baru.
- Suite diorama dijalankan ulang setelah mengubah pembacaan field menjadi Texture2D.get_image agar mendukung ekspor; nol kegagalan.
- **12/12 pemeriksaan windowed diorama lulus**, nol error runtime selama alur: seluruh ID, jumlah prop/batch, penanda kasus, ray picking, klik mouse aktual Surabaya, data detail yang sesuai, reduced motion, lapisan analitis, menu lapisan, 2D dan hash world/RNG yang tetap.
- [Evidence jendela](map_lowpoly_20261119/final/qa.json) mencatat RTX 3050 Laptop 6 GB, Compatibility, jendela 1600×900. Sampel 90 frame setelah pemanasan: median 3,851 ms, p95 6,747 ms. Ini sampel lokal pada tampilan nasional, bukan jaminan performa untuk semua perangkat/zoom.
- Screenshot aktual: [nasional](map_lowpoly_20261119/final/01_national.png), [Jawa Timur](map_lowpoly_20261119/final/02_jawa_timur.png), [Surabaya](map_lowpoly_20261119/final/03_surabaya.png), [lapisan analitis](map_lowpoly_20261119/final/04_analytical.png), [2D](map_lowpoly_20261119/final/05_2d.png).
- git diff --check lulus. QA tidak menulis simpanan pemain dan membandingkan hash world/RNG sebelum/sesudah.

## Yang gagal atau diperbaiki selama pengerjaan

- Kedua endpoint ZIP resmi Kenney mengembalikan HTTP 403. Tidak dicoba melewati pembatasan; dipilih distribusi CC0 GitHub publik, dengan lisensi upstream dan mirror tercatat.
- Normalisasi batu berdasarkan tinggi membuat footprint terlalu besar; diperbaiki dengan dimensi maksimum. Palet dan shading terang berlebihan pada renderer Compatibility diperbaiki sebelum screenshot final.
- Ketebalan dinding pulau yang seragam 25 unit membuat pulau kecil terlihat seperti tiang; jarak permukaan laut kini empat unit dan geometri pulau tetap dipertahankan.
- Ada error UI yang menghalangi kompilasi/render saat awal pekerjaan: konstanta INFO belum tersedia dan type variation pada tipe bawaan OptionButton/MenuButton. Perbaikan minimal mempertahankan perubahan UI lain yang sudah ada.
- Proses QA awal yang gagal dikompilasi dihentikan dengan pencocokan command line khusus sesi ini. Tidak menghentikan aplikasi pengguna.

## Batas dan tindak lanjut

- Belum memakai DEM/elevasi resmi atau data tutupan lahan; tidak menampilkan dekorasi sebagai data faktual.
- Tidak mengintegrasikan seluruh library FFT/terrain, tidak mengunduh koleksi besar tanpa kebutuhan, dan tidak membuat rute logistik/kejadian gameplay palsu.
- Model bangunan adalah miniatur generik, bukan representasi arsitektur daerah atau bangunan historis tertentu.
- Tidak membuat aset audio, ekspor standalone EXE baru, perubahan Figma, commit, push, atau publikasi.
- Tes headless masih melaporkan peringatan teardown CanvasItem/ObjectDB yang sudah ada pada baseline. QA renderer final mencatat nol error selama alur.
- Review visual oleh Galih/Cleo/Ananda tetap berguna; langkah selanjutnya bergantung pada arahan artistik setelah melihat preview.
