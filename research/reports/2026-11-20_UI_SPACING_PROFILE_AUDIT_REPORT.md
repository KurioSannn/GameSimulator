# Audit profil, avatar, edit nama, dan jarak bingkai

Tanggal: 20 November 2026, Asia/Bangkok. Lingkup: **audit saja**, mengikuti permintaan pengguna. UI produksi, font, aset, dan renderer peta tidak diubah.

## Hasil utama

Keluhan pengguna terkonfirmasi pada profil, HUD identitas, dan jarak kontrol terhadap bingkai dekoratif. Tombol yang diperiksa masih berada di dalam persegi panjang panel, tetapi beberapa terlalu dekat dengan sudut/tepi gambar bingkai. Pemeriksaan batas viewport sebelumnya belum mengukur ruang aman visual ini.

Fitur **edit nama pemain sudah ada dan penyimpanannya bekerja**. Kekurangannya ada pada penemuan fitur, pemisahan identitas pemain/karakter, dan umpan balik setelah menyimpan. Penggantian avatar belum tersedia.

## Cakupan dan metode

- 82 keadaan UI: 1280×720 dan 1920×1080, teks 100% dan 110%; HUD, profil, statistik, pengaturan, laporan terisi, bantuan, simpanan, konfirmasi mandat baru, warisan, menu, tiga kasus sebelum/sesudah pemilihan, anggaran, program, wilayah, dan sumber.
- Kasus yang diukur: CASE-0001, CASE-0006 yang dicontohkan pengguna, dan CASE-0008. Ini bukan pengulangan audit seluruh 27 kasus.
- 42 screenshot disimpan. Fixture kuartal kedua dibuat dalam proses uji terisolasi dengan memilih CASE-0001 B lalu menjalankan satu kuartal; fixture ini tidak berasal dari save pemain. Save dan preferensi uji diarahkan ke `.tmp/ui-spacing-audit-20261120/`.
- Sembilan observasi fitur tambahan memeriksa nama, simpan/buka ulang, nama kosong, dan Enter. Tidak ada runtime error. Hash world setelah fixture dibuat tetap sama sepanjang pemeriksaan UI/nama.
- Pengukuran memakai koordinat kontrol Godot, kemudian dikalikan skala jendela untuk piksel keluaran. Untuk bingkai tekstur, margin nine-slice dipakai sebagai **perkiraan konservatif** area aman; bentuk piksel kayu/logam tidak selalu sama dengan persegi panjang itu. Kandidat perlu dibaca bersama screenshot. Item yang terpotong alami oleh scroll dicatat terpisah.
- Baseline SHA-256 mencakup 23 file UI/wiring/config produksi. Verifikasi akhir menemukan 22 tetap sama dan `game/src/ui/hud.gd` berubah di workspace selama sesi; proses audit ini tidak menulis file produksi tersebut. Temuan HUD mengacu pada capture dan geometri runtime yang tersimpan, bukan jaminan seluruh HUD terbaru identik. Verifikasi tidak bergantung pada status Git yang sudah berisi pekerjaan sebelumnya.

## Temuan

### P1 — Aturan jarak isi dan bingkai belum konsisten

`GameSkin.frame()` memakai content inset 20 dan texture slice 24. HUD identitas lebih sempit: inset 12 dengan slice 24. Banner memakai inset horizontal 16 dengan slice 30. Akibatnya ukuran konten dapat lolos pemeriksaan panel, tetapi belum memberi ruang yang cukup terhadap ornamen.

Contoh terukur pada CASE-0006: tombol Wilayah berjarak 20 unit dari sisi kiri/bawah panel, dan Tetapkan keputusan berjarak 20 unit dari sisi kanan/bawah. Perkiraan area aman slice adalah 24 unit; selisihnya 4 unit. Pada 1920×1080 itu sekitar 5,3 piksel. Ini bukan klaim seluruh tepi panel melanggar piksel kayu: persoalan paling jelas ada di dekat sudut dan footer.

| Keadaan 1280×720, teks 100% | Tombol terlihat | Kandidat area aman, tanpa item scroll terpotong | Tombol terlihat di luar persegi panjang panel |
|---|---:|---:|---:|
| HUD | 8 | 3 | 0 |
| CASE-0006, belum memilih | 7 | 7 | 0 |
| Anggaran | 3 | 3 | 0 |
| Program | 9 | 1 | 0 |
| Wilayah | 5 | 4 | 0 |
| Sumber | 1 | 1 | 0 |

Angka kandidat tidak berarti semuanya cacat visual. Misalnya, sisi lurus kayu lebih tipis daripada sudut logam. Tabel menunjukkan pola shared style yang perlu diberi aturan, bukan daftar pelanggaran piksel yang sudah disertifikasi.

Bukti: [kasus Sabu Raijua 110%](ui_spacing_audit_20261120/CASE-0006_1280_110.png), [anggaran](ui_spacing_audit_20261120/budget_1280_100.png), [wilayah](ui_spacing_audit_20261120/region_1280_100.png), dan [program](ui_spacing_audit_20261120/policy_1280_100.png).

Sumber kode: `game/src/ui/game_skin.gd:18`, `:35`, `:43`; default frame dipakai ulang oleh case, budget, policy, region, dan sources dialog.

Usulan perbaikan: definisikan ruang aman isi, ornamen, dan padding teks tombol secara terpisah. Sebagai target review, sediakan tambahan 8–12 unit setelah batas sudut dekoratif pada frame luar. Setelah aturan bersama berubah, hitung ulang tinggi dialog dan posisi HUD; jangan menaikkan padding global tanpa memeriksa reflow.

### P1 — Avatar HUD belum menjadi komponen identitas yang stabil

HUD menggunakan panel dengan inset 12, lalu tombol profil yang berisi HBox absolut sepanjang tombol. Susunan ini tidak memakai wadah portrait dengan ruang dalam sendiri. Avatar berjarak 12 unit dari kiri panel, sementara slice sudutnya 24; tepi atas/bawah avatar berjarak 21 unit. Ini menjelaskan kesan menempel/keluar ke area logam pada screenshot pengguna.

Crop sumber avatar berasio sekitar 1,094, tetapi dipaksa menjadi persegi dengan `STRETCH_SCALE`. Skala horizontal relatif terhadap vertikal sekitar 0,914: potret sedikit terkompresi horizontal. Latar persegi dari crop masih terlihat dan tidak diberi mask/frame portrait khusus. Hal serupa dipakai pada avatar kecil di profil.

Bukti: [HUD 1920](ui_spacing_audit_20261120/hud_1920_100.png), [geometri avatar](ui_spacing_audit_20261120/summary.json). Sumber: `game/src/ui/hud.gd:64`, `:69`; `game/src/ui/figma_assets.gd:32`.

Usulan: satu komponen portrait bersama dengan crop/aspect yang konsisten, ruang dalam terhadap ornamen, dan alignment vertikal yang mengikuti nama/kalender. Pertahankan ilustrasi yang ada; audit ini tidak mengusulkan gambar generatif baru.

### P1 — Edit nama bekerja, tetapi tampil seperti data biasa

Hasil verifikasi:

| Fungsi | Status saat ini |
|---|---|
| Ubah nama pemain | Ada; LineEdit editable, batas 30 karakter |
| Simpan nama lalu buka ulang profil | Berhasil dalam preferensi uji |
| Nama karakter di HUD | Tetap Nara Adinata; berbeda dari nama pemain |
| Ganti/pilih avatar | Belum ada kontrol atau preference untuk itu |
| Edit jabatan/masa bakti/statistik | Tidak tersedia; berasal dari karakter dan state permainan |

Field nama memakai warna isi yang sama dengan kartu profil, dengan border putih tipis. Tidak ada penanda edit yang kuat, pesan sukses, status perubahan, atau state tombol yang membedakan sudah/belum tersimpan. Nama pemain juga tidak muncul pada identitas HUD, sehingga perubahan bisa terasa tidak berpengaruh meski sudah tersimpan.

Ada perilaku yang perlu dirapikan: nama kosong dinormalisasi menjadi “Pemain” dalam penyimpanan, tetapi field tetap kosong sampai profil dibuka ulang. Enter pada field tidak menyimpan karena `text_submitted` tidak dihubungkan ke aksi simpan. Tombol simpan tetap aktif tanpa status perubahan. Ini tidak membuktikan penyimpanan gagal.

Bukti: [nama berhasil disimpan](ui_spacing_audit_20261120/profile_name_saved_1600.png), [field kosong setelah simpan](ui_spacing_audit_20261120/profile_empty_name_after_save_1600.png), [observasi fitur](ui_spacing_audit_20261120/name_checks.json).

Sumber: `game/src/ui/desktop_screens.gd:442`, `:449`; `game/src/ui/ui_preferences.gd:7`, `:30`; `game/src/ui/stitch_theme.gd:84`.

Usulan: perjelas field yang bisa diedit, beri umpan balik tersimpan, sinkronkan field setelah normalisasi, dan tentukan perilaku Enter/batal. Pisahkan identitas pemain dari karakter secara jelas. Nara Adinata adalah nama karakter yang ditetapkan kontrak proyek; audit ini tidak menyamakan edit nama pemain dengan mengganti tokoh.

### P2 — Karakter besar terlihat melayang di atas platform

Ilustrasi dan elips biru adalah dua anak VBox terpisah. Ilustrasi mendapat ruang vertikal yang dapat melebar dan memakai KEEP_ASPECT_CENTERED, sedangkan elips tetap pada tinggi 26. Tidak ada acuan posisi telapak kaki terhadap lantai.

Proyeksi bounding box alpha ilustrasi asli menunjukkan jarak sekitar 10,8 unit dari piksel telapak terbawah ke bagian atas elips. Hasilnya sekitar 9,6 piksel pada 1280×720 dan 14,4 piksel pada 1920×1080. Warna elips `#437BC6` juga tampak sebagai platform biru, bukan bayangan kontak yang menyatu dengan latar kertas. Ambang alpha analisis 32; nilai ini merupakan perkiraan raster, bukan hasil pengukuran fisika karakter.

Bukti: [profil 1920](ui_spacing_audit_20261120/profile_1920_100.png). Sumber: `game/src/ui/desktop_screens.gd:420`, `:423`; SVG `game/assets/ui/figma/2_PermukaanPanggung_bfc4c.svg`. Perhitungan dapat direproduksi dengan [script analisis](ui_spacing_audit_20261120/analyze_spacing.py).

Usulan: letakkan karakter dan shadow/platform dalam satu komponen dengan acuan telapak yang stabil. Sesuaikan warna/bentuk grounding dengan permukaan profil. Mengubah jarak VBox saja tidak menyelesaikan ruang transparan/letterbox pada semua ukuran.

### P2 — Komposisi profil belum sekuat layar lainnya

Karakter besar mendominasi tengah, sementara fitur edit berada di kartu kanan yang tampak sebagai panel statistik. Informasi tahun/masa bakti/nama karakter berulang pada beberapa lokasi. Medali, pill tahun, elips, dan nameplate masih memakai gaya dari komposisi lama sehingga profil terasa kurang menyatu dengan frame game baru.

Usulan minor: jadikan identitas/edit pemain mudah ditemukan, jadikan ilustrasi sebagai satu objek dengan grounding yang benar, lalu atur ulang hierarki mandat dan medali. Pertahankan font, palet, dan aset game yang sekarang; tidak perlu mengganti arah visual seluruh permainan.

## Mengapa pemeriksaan lama belum menangkap ini

`QaUiRuntime._buttons_fit()` memeriksa apakah persegi panjang tombol berada dalam viewport. Pemeriksaan tambahan sebelumnya memeriksa label dalam kartu dan ukuran dialog. Keduanya berguna untuk fungsi/overflow, tetapi belum mengukur jarak terhadap ornamen, keterbacaan field edit sebagai aksi, maupun kontak kaki dengan platform.

Dalam 82 keadaan audit ini tidak ditemukan tombol **tanpa clipping** di luar batas persegi panjang panel/viewport. Temuan pengguna tetap valid: area yang tampak aman di dalam tekstur berbeda dari batas kontrol. Item list/source yang terpotong oleh scroll tidak otomatis ditandai sebagai bug.

## Pelaksanaan, batas, dan tindak lanjut

- Berhasil: 82 keadaan/42 screenshot; pemeriksaan jarak terhadap slice-safe area; verifikasi nama yang tersimpan; pengukuran avatar/grounding; perbandingan hash file produksi. Audit ini tidak melakukan perubahan UI; perubahan workspace pada `hud.gd` dicatat sebagai batas verifikasi.
- Percobaan awal pengisian nama menggunakan `insert_text_at_caret()` setelah seleksi ternyata menambahkan teks, sehingga dua assertion fixture awal gagal. Input probe diperbaiki dan diuji ulang secara terpisah; sembilan observasi final benar. Ini kegagalan harness, bukan kegagalan fitur simpan nama. Inventaris awal tetap disimpan agar jejaknya tidak hilang.
- Pembacaan SVG dengan PIL tidak didukung; ukuran elips diambil dari SVG dan geometry runtime. Ilustrasi PNG dianalisis menggunakan alpha tanpa mengubah bitmap.
- Tidak dilakukan: perbaikan UI, penambahan editor avatar, penggantian gambar, perubahan Figma, perubahan peta/simulasi, atau tes regresi gameplay ulang. Tidak ada sumber eksternal/aset baru yang diambil.
- Batas: dua resolusi 16:9 dan dua skala teks; tidak menguji ultrawide, DPI OS lain, seluruh popup native, atau semua 27 kasus. Perhitungan slice-safe area bersifat konservatif dan belum merupakan mask piksel ornamen.

Urutan tindak lanjut yang disarankan: **kontrak spacing bersama → komponen avatar HUD → affordance/feedback edit nama → grounding dan hierarki profil → pemeriksaan visual lintas layar**. Ini usulan hasil audit, bukan perubahan yang sudah diterapkan.

Evidence: [inventaris 82 keadaan](ui_spacing_audit_20261120/inventory.json), [ringkasan pengukuran](ui_spacing_audit_20261120/summary.json), [observasi nama final](ui_spacing_audit_20261120/name_checks.json), [driver audit](ui_spacing_audit_20261120/audit_spacing.gd).

Katalog bukti lokal: [provenance audit](../sources/ui_spacing_audit_2026-11-20.json). Tidak ada sumber eksternal baru.
