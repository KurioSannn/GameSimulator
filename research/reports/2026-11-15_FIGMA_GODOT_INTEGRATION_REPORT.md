# Integrasi Figma ke Godot: 15 November 2026

Pelaksana: ChatGPT / Codex. Pengguna meminta perubahan Figma diterapkan ke game. Pembersihan C dilakukan lebih dahulu atas permintaan pengguna; Downloads dikecualikan.

## Hasil

Tujuh tampilan audit dan Detail Wilayah tersedia sebagai antarmuka Godot, terhubung ke sistem game:

| Tampilan | Perilaku runtime |
| --- | --- |
| Menu awal | Mulai mandat, kembali ke pemerintahan aktif, daftar simpanan lokal, bantuan dan pengaturan. Mandat baru saat bermain membuat simpanan terpisah terlebih dahulu. |
| Beranda | Enam indikator nasional dari state 514 wilayah, profil, statistik, anggaran, kebijakan, lapisan/cakupan peta, agenda dan lanjut kuartal. |
| Profil | Nara Adinata, tahun mandat, nama pemain sebagai preferensi, kasus dan lencana berdasarkan progres. Peninjauan wilayah ditandai sebagai hitungan sesi. |
| Statistik | Nilai nasional dan pengamatan bulanan kuartal terakhir. Setelah load, grafik hanya memakai awal/akhir ledger yang tersedia. |
| Pengaturan | Volume bus audio, layar/resolusi, MSAA 3D, tombol geser, skala teks 100/110%, kurangi gerakan. Simpan/batal/default tidak mengubah progres simulasi. |
| Keputusan | Fakta bersumber, narasi fiksi, peta nyata, biaya/waktu opsi, tanda terpilih, ringkasan dan konfirmasi. Tombol 1–9 hanya memilih; Enter menetapkan. |
| Laporan | Sebelum/sesudah, delta, peristiwa dan penyebab dari ledger. Peta dampak dapat membuka Detail Wilayah. |
| Detail Wilayah | Satu adapter untuk kab/kota, provinsi, kelompok pulau dan nasional. Enam indikator, kasus dan kebijakan sesuai cakupan; fakta/sumber terpisah. |

Launcher Windows: Mainkan NUSANTARA.cmd di root proyek. Memakai Godot bawaan tools/godot dan membuka menu; melakukan import awal jika indeks kelas belum tersedia. Tidak ada ekspor standalone EXE baru.

## Integritas data dan simulasi

- Tidak mengubah raw data, parameter simulasi, cakupan 514 entitas, format save atau hasil golden master.
- Adapter hanya membaca state; pengujian membandingkan serialisasi world/RNG sebelum dan sesudah penyusunan UI.
- Rata-rata indikator memakai penduduk dalam cakupannya. Bila bobot tidak lengkap, seluruh cakupan memakai rata-rata setara dengan label jelas.
- Fakta resmi berasal dari record kab/kota atau provinsi terkait. Kelompok pulau/nasional tanpa record acuan menampilkan ketidaktersediaan; tidak dibuat statistik resmi baru.
- Indeks harga tidak dibatasi menjadi 0–100; delta kepercayaan menggunakan poin persentase.
- Metadata diekspor dari registry yang ada beserta SHA-256 input. Reproduksi: python scripts/pipelines/game/export_ui_sources.py. Ekspor berisi 23 sumber; field kosong tidak diisi dugaan.
- Peta ilustratif Figma diganti dengan mesh GIS offline yang sama pada peta utama/kasus/laporan, sesuai kontrak geografi proyek.
- Riwayat bulanan transient tidak disisipkan ke save. Setelah load, titik yang tidak tersimpan tidak direka.

## Aset dan gaya

Sumber: Figma xXZj1Xnoxln1coG2yEO81a, konteks resolusi tinggi tujuh layar audit dan komponen 65:16837.

- 120 aset lokal diverifikasi tidak kosong; format/ukuran/SHA-256 dicatat di game/assets/ui/figma/manifest.json.
- Lima unduhan berakhiran PNG ternyata JPEG; hanya ekstensi lokal diperbaiki. Potret mengikuti crop image fill dengan AtlasTexture.
- Lilita One dan Inter berasal dari repositori resmi Google Fonts, disertakan bersama lisensi OFL.
- Layout memakai container native. Peta/grafik dinamis tidak memakai screenshot prototipe.
- Fokus bergaris putih, navigasi dialog terarah, dan kamera diblokir ketika menu/dialog terbuka.

## Verifikasi

Engine: Godot 4.7.stable.official.5b4e0cb0f, Windows, Compatibility/OpenGL, NVIDIA RTX 3050.

- Regresi mencakup simulasi, kasus/golden master, determinisme, kebijakan, budget, save/load, peta dan kompilasi skrip. Enam regresi adapter/akhir mandat ditambahkan.
- QA jendela/input: ui_runtime_20261115/flow/qa_ui.json. Eksekusi akhir mencatat jumlah pemeriksaan dan error. Termasuk input mouse/keyboard, reset konteks, volume aktual, simpanan identik dan preferensi terisolasi.
- Jendela nyata 1280×720; profil/statistik/pengaturan/laporan pada skala teks 100% dan 110%. Profil dan provinsi juga dirender pada 1920×1080.
- Screenshot akhir di ui_runtime_20261115/flow/. Simpanan/config uji terisolasi dan diabaikan Git.
- Metadata kosong sempat menyebabkan error tipe; telah diperbaiki menjadi belum tercatat, tanpa meminjam fakta lain.

Hasil akhir: **147/147 tes headless lulus** dan **120/120 pemeriksaan UI lulus**, termasuk 83 pengamatan aset terlihat. Evidence final mencatat nol error runtime selama alur. git diff --check lulus setelah normalisasi newline berkas panel.

## Batas dan pekerjaan yang tidak dilakukan

- Kabinet belum menjadi sistem gameplay; tombol menjelaskan ketidaktersediaannya. Tidak dibuat statistik PDB/APBN rupiah palsu untuk mengisi prototipe.
- Lima variabel awal yang belum terkalibrasi tetap ditandai. Nilai model dan proksi tetap dijelaskan.
- Audio/voice baru tidak dibuat; preferensi terhubung ke bus audio untuk integrasi aset terpisah.
- Log penutupan Godot masih memuat peringatan CanvasItem/ObjectDB yang juga terlihat pada baseline; beberapa GUI melaporkan RID FontAdvanced saat keluar. Alur UI yang berhasil mencatat nol error selama berjalan. Teardown engine tidak ditangani dalam fase antarmuka ini.
- Tidak ada perubahan lanjutan ke Figma, publikasi, commit atau push.

## Langkah berikutnya

Review visual/interaksi oleh Galih dan tim. Aset audio, sistem kabinet, dan ekspor distribusi memakai template Godot yang sesuai merupakan pekerjaan terpisah bila diminta.
