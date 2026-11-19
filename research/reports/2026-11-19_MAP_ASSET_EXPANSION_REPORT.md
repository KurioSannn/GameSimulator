# Perluasan aset dan atmosfer peta — 19 November 2026

Otorisasi: pengguna meminta lebih banyak shader, awan, rumah, gedung dan aset lain setelah remake low-poly pertama. Pelaksana: ChatGPT/Codex. Keputusan: D-081.

## Hasil

Perubahan sudah terintegrasi ke renderer Godot dan dikemas untuk runtime offline. Pilihan model bertambah dari delapan menjadi **48**, dengan **9405 objek dekoratif** dalam 48 batch model dan **36 gugus awan** dalam satu batch tambahan. Jumlah objek awal 2298; hasil akhir sekitar 4,1 kali lipat. Jumlah akhir mengikuti hasil fitting polygon, bukan target statistik permukiman.

| Kelompok | Varian model | Objek terpasang |
| --- | ---: | ---: |
| Rumah | 12 | 2647 |
| Gedung menengah | 8 | 62 |
| Menara | 4 | 98 |
| Jalan | 4 | 1338 |
| Lampu jalan | 2 | 564 |
| Pohon | 6 | 2522 |
| Palem | 4 | 640 |
| Semak | 4 | 1336 |
| Batu | 4 | 198 |
| Total prop | 48 | 9405 |

Setiap 514 kabupaten/kota memiliki inti dekoratif di dalam triangle kanonik. Model inti dan blok di sekitarnya memakai skala sesuai ruang yang tersedia; tidak ada pemindahan objek ke wilayah tetangga agar jumlah terlihat lebih besar. Rotasi blok, pilihan model, tinggi dan warna atap bervariasi. Jalan berada di samping gedung inti, bukan melintang melalui gedung tersebut.

Ukuran, kelompok dan pilihan model berasal dari satu katalog: `game/data/map/art_catalog.json`. Pipeline unduh, penempatan dan renderer membaca katalog yang sama. Ukuran GLB total **3.468.000 byte**. GLB asli tidak diedit; penyesuaian palet terjadi melalui shader runtime.

## Shader dan atmosfer

- Shader bangunan baru mempertahankan detail tekstur, memberi variasi atap rumah dan kilau hangat yang ringan pada texel jendela gelap. Ini bukan siklus siang/malam baru.
- Shader vegetasi menambah variasi warna antar-instance serta goyangan dua arah dengan gust ringan.
- Fungsi atmosfer bersama memberi variasi pencahayaan awan yang lembut pada bentang, prop dan laut. Ini efek artistik prosedural, bukan proyeksi bayangan fisik yang mengikuti setiap mesh awan.
- Shader laut menambah caustics dekoratif dekat pantai, pecahan buih dan gelombang pesisir. Field jarak tetap diturunkan dari mesh asli; tidak ditampilkan sebagai kedalaman laut terukur.
- Gugus awan memakai enam lobe yang digabung sekali menjadi mesh bersama. Ada variasi ukuran, arah, warna, fase gerak dan tiga ketinggian. Kamera dekat memperkecil seluruh gugus, menjaga bentuk tetap menyatu dan mengurangi gangguan saat memeriksa wilayah.
- Preferensi kurangi gerakan membekukan air, angin vegetasi, drift awan dan pencahayaan ambient. Semua dekorasi disembunyikan pada lapisan indikator; warna indikator tidak dimodifikasi shader atmosfer.

## Sumber dan lisensi

Halaman pembuat diperiksa langsung:

- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit): 18 model alam.
- [Kenney City Kit (Suburban)](https://kenney.nl/assets/city-kit-suburban): 12 rumah.
- [Kenney City Kit (Commercial)](https://kenney.nl/assets/city-kit-commercial): delapan gedung dan empat menara.
- [Kenney City Kit (Roads)](https://kenney.nl/assets/city-kit-roads): empat jalan dan dua lampu.

Keempat halaman mencantumkan CC0. GLB konversi berasal dari [mirror publik Hidencod/tge-assets](https://github.com/Hidencod/tge-assets), commit `01e09f8f034c6abf1254cd4cd35aaa60ce310b31`. Pemberitahuan lisensi, URL sumber/download, timestamp unduhan lokal, ukuran dan SHA-256 disimpan dalam `game/assets/map/kenney/`. Kode repository luar tidak dijalankan. Katalog sumber: [map_visual_research_2026-11-19.json](../sources/map_visual_research_2026-11-19.json).

City Kit Industrial turut ditinjau, tetapi tidak dibundel: pack itu tidak ada dalam revisi mirror terpilih. Tidak menambahkan URL model tebakan atau koleksi lain tanpa kebutuhan.

## Integritas dan reproduksi

Dekorasi rumah, gedung, jalan, vegetasi, batu dan awan adalah **miniatur artistik**, bukan koordinat bangunan, jaringan jalan, kepadatan penduduk, tutupan lahan, elevasi atau batimetri resmi. Letak inti memakai centroid triangle interior; tidak diklaim sebagai pusat kota yang terukur. Penjelasan dekorasi tetap terlihat pada legenda bentang.

Seluruh 514 ID, mesh GIS LOD, state dan RNG simulasi, observasi sumber, format save dan input gameplay dipertahankan. Runtime tidak membutuhkan Python atau jaringan. Penempatan memakai RNG dekorasi tersendiri dan seed 20261119.

Reproduksi dari root repository, dengan dependency build yang dipatok:

    python scripts/pipelines/game/fetch_map_art.py
    python scripts/pipelines/game/build_map_art.py

Dua build berturut-turut menghasilkan JSON identik, termasuk newline LF eksplisit:

    e64d6212844bf4228e8e8f50ea864ad1047387c7eb2b2042a7a1ef53340fa2e2

SHA-256 katalog:

    b0799c93fc5423326a874192de7c110ad36623327b35c32242942f6e3af5b313

[Bukti reproduksi](map_expansion_20261119/reproducibility.json). SHA-256 input GIS asli tetap `b8e256391243b104d7aab5325a82f06026162328fd875a5de082c6bb7b29aa34`.

## Verifikasi

- **152/152 tes headless lulus**, termasuk empat tes diorama. Seluruh anchor dicek terhadap wilayah kanonik, setiap inti hadir, seluruh 48 model terpakai, checksum/lisensi terkemas, field pantai sesuai dan awan berawal di laut terbuka.
- Tes penempatan tambahan memeriksa pusat, empat sudut dan empat titik tengah sisi footprint blok terhadap polygon wilayahnya. Ini validasi sembilan sampel per footprint, bukan bukti geometris seluruh kontur di antara sampel.
- **16/16 pemeriksaan windowed lulus**, nol error runtime: 514 ID, semua prop, batching, awan, penanda kasus, ray picking, klik mouse aktual, Detail Wilayah Surabaya, lift semua material prop, kurangi gerakan, lapisan analitis, menu lapisan, mode 2D dan hash world/RNG yang tetap.
- [Evidence QA](map_expansion_20261119/final/qa.json): Compatibility, RTX 3050 Laptop 6 GB, jendela 1600×900. Sampel nasional 90 frame: median **4,394 ms**, p95 **5,275 ms**. Sampel dekat 60 frame: median **6,538 ms**, p95 **7,967 ms**. Ini sampel lokal setelah pemanasan, bukan jaminan semua perangkat.
- Screenshot aktual ditinjau: [nasional](map_expansion_20261119/final/01_national.png), [Jawa Timur](map_expansion_20261119/final/02_jawa_timur.png), [Surabaya](map_expansion_20261119/final/03_surabaya.png), [detail permukiman](map_expansion_20261119/final/03b_settlement_detail.png), [indikator](map_expansion_20261119/final/04_analytical.png), [2D](map_expansion_20261119/final/05_2d.png).
- `git diff --check` lulus setelah normalisasi newline log penggunaan AI.

## Kegagalan dan koreksi selama pengerjaan

- Sandbox awal menghalangi jaringan, certificate store Windows, cache shader dan penyimpanan setting editor. Unduhan dan QA diulang dengan akses yang disetujui auto-review; QA final nol error runtime.
- Awan awal mengecil per-lobe sehingga bentuk tampak terpisah. Lobe digabung menjadi satu mesh sebelum instancing; bentuk kini mengecil secara utuh.
- Klaster awal terlalu seragam dan inti memotong jalan. Tata blok, arah dan warna atap diperbaiki; objek yang tidak muat disisihkan dari dekorasi tanpa mengubah cakupan wilayah simulasi.
- Penambahan pemeriksaan QA sempat memiliki kesalahan sintaks lambda multiline. Dikoreksi, hanya proses QA milik sesi ini dihentikan, lalu seluruh alur renderer diulang hingga lulus.
- Tes headless masih mengeluarkan peringatan teardown dua CanvasItem/lima ObjectDB yang telah ada pada baseline. Pemeriksaan renderer final tidak mencatat error.

## Cakupan dan batas

Tidak ada Figma baru, perubahan data resmi atau aturan gameplay pada fase ini. Tidak ada aset industri yang dibundel, DEM baru, audio, kendaraan/rute logistik baru, ekspor standalone EXE, commit atau publikasi. Aset yang ditambahkan adalah bangunan generik; tidak diklaim mewakili arsitektur daerah tertentu. Folder Downloads tidak disentuh.

Perubahan siap dimainkan dari launcher Windows yang ada. Review visual oleh Galih/Cleo/Ananda dapat menentukan arah artistik lanjutan.
