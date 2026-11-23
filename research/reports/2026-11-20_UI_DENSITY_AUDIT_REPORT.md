# Audit kepadatan UI dan teks NUSANTARA

Tindak lanjut: pengguna menyetujui implementasi dan memberi koreksi arah visual/tipografi. Hasil runtime terbaru dicatat dalam [laporan implementasi](2026-11-20_UI_IMPLEMENTATION_REPORT.md); isi audit di bawah tetap menjadi catatan kondisi sebelumnya.

Tanggal: 20 November 2026 (Asia/Bangkok). Pelaksana: ChatGPT/Codex.

## Hasil utama

Keluhan pengguna terbukti pada build Godot saat ini: terlalu banyak kelompok informasi muncul bersamaan, ukuran teks kecil, informasi berulang, dan banyak kartu memperoleh penekanan visual serupa. Masalah ini perlu diselesaikan sebelum memilih skin UI. Mengganti gambar tombol/panel saja akan mempertahankan kepadatan yang sama.

Ini **audit dan riset**, bukan persetujuan arah visual baru. Tidak ada perubahan source UI produksi, instalasi library, perubahan konten kasus, atau integrasi mockup dalam fase audit ini. Konsep HTML sebelumnya dihentikan setelah arahan pengguna. Screenshot di laporan ini berasal dari game yang berjalan, bukan gambar generatif.

Catatan lama bahwa desain Figma belum terintegrasi sudah tidak menggambarkan keadaan sekarang: integrasi native Godot tercatat dalam [laporan 15 November](2026-11-15_FIGMA_GODOT_INTEGRATION_REPORT.md). Audit ini memeriksa implementasi runtime tersebut beserta perubahan workspace saat ini.

## Cakupan dan bukti

- Godot 4.7 stable, Windows, Compatibility renderer, NVIDIA RTX 3050 Laptop GPU; jendela 1600×900 dan 1280×720, pengaturan teks 100%, viewport internal 1920×1080.
- 13 screenshot: peta nasional, Detail Wilayah Kota Surabaya, Detail Wilayah Jawa Timur, anggaran di atas detail, kebijakan provinsi, CASE-0001, profil, statistik, laporan awal, dan pengaturan. Kedua ukuran diuji pada peta, detail kota, dan keputusan; layar lainnya pada satu ukuran.
- [Inventaris kontrol dan ukuran](ui_audit_20261120/inventory.json), [log runtime](ui_audit_20261120/runtime.log), serta [driver audit](ui_audit_20261120/audit_current_ui.gd) disimpan untuk reproduksi.
- Tidak menjalankan keputusan atau memajukan waktu. Hash serialisasi world sebelum/sesudah identik: `c91dc1edffe9454c5efa017eb44a61997eadde513776c4f2ec692bee788ad5ab`. Audit memakai path save terisolasi dan tidak menyimpan pengaturan pengguna.

## Temuan berprioritas

### P0: Teks menyusut bersama seluruh layout

[`project.godot:18`](../../game/project.godot#L18) menetapkan viewport 1920×1080 dengan `canvas_items`. Banyak label memakai 11–14 unit font. Dalam konfigurasi audit, pada 1280×720 ukuran efektifnya sekitar 7,3–9,3 px; pada 1600×900 label 11 unit sekitar 9,2 px. Di CASE-0001 ukuran efektif seluruh blok berkisar 7,3–16 px pada 1280×720. Teks manfaat 14 unit menjadi sekitar 9,3 px; risiko 13 unit sekitar 8,7 px; sumber 12 unit sekitar 8 px.

Layar keputusan memiliki area kosong besar di bawah kartu pilihan pada 1600×900, sementara konteks, risiko, dan manfaat tetap kecil. Pengaturan juga memiliki kartu besar dengan teks kecil. Ini ketidakseimbangan pembagian ruang, bukan kekurangan ruang secara menyeluruh.

Bukti: [keputusan 1600](ui_audit_20261120/06_case_1600.png), [keputusan 1280](ui_audit_20261120/09_case_1280.png), [pengaturan 1280](ui_audit_20261120/10_settings_1280.png). Sumber: `game/src/ui/case_modal.gd:99` (area fakta), `:198` (kartu pilihan), `game/src/ui/ui_kit.gd` (ukuran label).

Tindak lanjut yang disarankan: tetapkan ukuran baca pada output desktop dan uji pembesaran teks sebelum menambah dekorasi. Ambang 12 px di audit ini hanya alat penyaringan; bukan sertifikasi aksesibilitas. [XAG 101 Microsoft](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101) juga membedakan pengukuran tinggi glyph dari angka font dan menekankan keterbacaan serta konfigurasi teks.

### P0: Detail Wilayah membuka terlalu banyak tingkat informasi sekaligus

Peta awal menampilkan 49 blok teks. Membuka detail kota menaikkannya menjadi 81 pada 1600×900: enam indikator nasional tetap di atas, enam indikator wilayah di dalam drawer, identitas/kode administratif, peristiwa aktif, data resmi, kebijakan, penjelasan model, tombol rincian, dan footer. Dua bagian kosong masih meminta perhatian lewat panel, judul, dan penghitungnya.

Bukti: [peta awal](ui_audit_20261120/01_map_1600.png), [detail kota](ui_audit_20261120/02_region_1600.png), [detail provinsi](ui_audit_20261120/03_province_1600.png), [detail 1280](ui_audit_20261120/08_region_1280.png). Sumber: `game/src/ui/region_panel.gd:87`, `:124`, `:132`, `:144`, `:149`.

Tindak lanjut yang disarankan: pisahkan ringkasan yang membantu tindakan saat ini dari rincian indikator, administrasi, penyebab, dan sumber yang dibuka saat diperlukan. Pertahankan akses ke fakta, unit, resolusi geografis, dan provenance; jangan menghapus datanya atau membuat label simulasi/fakta menjadi ambigu. Komponen tetap harus berlaku untuk seluruh konteks peta, bukan khusus Jawa Timur.

### P1: Agenda dan indikator ditampilkan berulang

Judul kasus yang sama muncul pada agenda kanan dan agenda bawah di peta awal. Periode mandat juga muncul di profil atas dan dock bawah. Di statistik, kesejahteraan/sentimen/lingkungan diulang sebagai bar dan kartu angka; kepercayaan muncul sebagai ringkasan grafik dan kartu bawah. Beberapa pengulangan bisa membantu konteks, tetapi sekarang semuanya permanen.

Bukti: [peta awal](ui_audit_20261120/01_map_1600.png), [statistik](ui_audit_20261120/10_statistics_1280.png). Sumber: `game/src/ui/hud.gd:56`, `:197`, `:299`; `game/src/ui/desktop_screens.gd:535`, `:611`.

Tindak lanjut yang disarankan: tentukan satu tempat utama untuk agenda dan status waktu. Setiap pengulangan harus punya fungsi tambahan yang jelas. Pilih ringkasan statistik yang mendukung pertanyaan pemain, bukan menambahkan kartu angka untuk semua data yang tersedia.

### P1: Terlalu banyak elemen bersaing menjadi tindakan utama

Tombol Ambil Keputusan, Lanjutkan Kuartal, dan Atur Kebijakan sama-sama mendapat warna kuning. Lanjutkan Kuartal memang diblokir saat kasus belum selesai, tetapi bentuk dan luasnya tetap dominan. Tombol Kebijakan di sidebar selalu memakai variasi ungu `ButtonAccent` berdasarkan jenis tombol, sehingga warna tersebut tidak menyatakan konteks aktif. Kabinet yang belum tersedia juga tetap menempati navigasi utama.

Bukti: [detail 1280](ui_audit_20261120/08_region_1280.png). Sumber: `game/src/ui/hud.gd:128`, `:166`, `:299`.

Tindak lanjut yang disarankan: satu tindakan mendapat penekanan tertinggi sesuai tahap permainan; bedakan status aktif, belum tersedia, dan aksi sekunder secara konsisten. Pertahankan aturan blokir kemajuan kuartal.

### P1: Panel bertumpuk secara visual meski input sudah diblokir

Saat anggaran dibuka di atas detail provinsi, drawer, indikator, sidebar, dan dock masih terlihat di balik lapisan redup. Kasus dan kebijakan juga menyisakan banyak kontur HUD di belakangnya. `_sync_interaction()` mengatur interaksi/fokus, tetapi redupnya latar tidak menghilangkan kompetisi bentuk dan teks.

Bukti: [anggaran di atas detail](ui_audit_20261120/04_budget_over_region_1600.png), [kasus](ui_audit_20261120/06_case_1600.png), [kebijakan](ui_audit_20261120/05_policy_1600.png). Sumber: `game/src/app/main.gd:877`.

Tindak lanjut yang disarankan: tampilkan konteks belakang secukupnya saat tugas keputusan aktif. Hindari dua lapisan panel lengkap yang sama-sama terbaca. Tidak ada perubahan perilaku penutupan atau fokus dalam audit ini.

### P2: Identitas visual dan peta ikut menambah beban perhatian

Kartu navy berulang, header kuning, aksen ungu, garis terang, awan putih, serta detail air/pulau sama-sama kuat. Penilaian visual audit: pola kartu, sidebar, dan deretan KPI memberi kesan dashboard. Menambahkan border ornamental atau lebih banyak shader berpotensi memperberat layar yang sama.

Drawer juga menutup bagian timur peta dalam jalur pembukaan konteks yang direkam, karena framing masih menggunakan viewport penuh. Ini bukti untuk jalur programatis audit, bukan klaim semua klik wilayah selalu menghasilkan framing yang sama. Perlu diperiksa terpisah dengan interaksi mouse alami.

Bukti: [peta 1600](ui_audit_20261120/01_map_1600.png), [detail 1600](ui_audit_20261120/02_region_1600.png). Sumber: `game/src/app/main.gd:271`, `:757`, `:829`.

## Ringkasan pengukuran

| Keadaan | Blok teks | Kata, batas atas | Blok dengan estimasi font <12 px |
|---|---:|---:|---:|
| Peta 1600×900 | 49 | 121 | 30 |
| Detail kota 1600×900, termasuk HUD | 81 | 198 | 52 |
| Detail provinsi 1600×900, termasuk HUD | 79 | 189 | 52 |
| Kebijakan 1600×900, panel aktif | 35 | 125 | 19 |
| Keputusan 1600×900, panel aktif | 48 | 246 | 38 |
| Peta 1280×720 | 49 | 121 | 41 |
| Detail kota 1280×720, termasuk HUD | 80 | 183 | 63 |
| Keputusan 1280×720, panel aktif | 48 | 246 | 45 |
| Statistik 1280×720 | 43 | 78 | 33 |
| Pengaturan 1280×720 | 39 | 89 | 33 |

Metode: hitung `Label`, `RichTextLabel`, dan `Button` yang terlihat setelah intersect viewport dan ancestor yang melakukan clipping. Kata dihitung dari teks kontrol penuh sehingga merupakan batas atas jika sebagian kontrol terpotong; bukan hasil OCR. Blok tidak sama dengan paragraf, satuan fakta, atau jumlah tindakan. Estimasi font = ukuran font theme × lebar jendela / lebar viewport internal; bukan tinggi glyph, ukuran monitor fisik, atau pengukuran DPI sistem.

Tidak ditemukan kandidat perpotongan antarkotak teks >20% dari kotak yang lebih kecil pada 13 keadaan. Ini mendukung diagnosis bahwa keluhan “numpuk” terutama berasal dari kepadatan informasi dan hirarki visual. Pemeriksaan geometris ini tidak membuktikan seluruh UI bebas masalah. Clipping alami pada scroll tetap tercatat. Luas panel dalam inventaris merupakan union persegi panjang, bukan luas piksel opak yang menutupi peta, sehingga tidak dipakai sebagai skor kenyamanan.

## Library dan aset UI yang sudah diperiksa

| Kandidat dan sumber pembuat | Yang tersedia | Lisensi / status verifikasi | Penilaian untuk NUSANTARA |
|---|---|---|---|
| [Themey: Clashy / Spacey](https://github.com/wadlo/Themey) | Theme `.tres` dan gambar untuk Godot 4.x; Clashy bergaya tombol berdimensi, Spacey bersih dengan nuansa sci-fi | Non-image MIT; gambar umumnya CC0; Material icons Apache 2.0 menurut README. Commit `678c5574b3a9274437c0c1e0ac15395056b5fc5f` dipin; README/lisensi/preview Spacey tersimpan | Pembanding native Godot yang paling langsung. Kecocokan Clashy belum dinilai dari preview karena unduhan preview gagal; bukan rekomendasi final. Belum diuji di runtime proyek. |
| [Kenney UI Pack: Adventure](https://kenney.nl/assets/ui-pack-adventure) | Listing 130 file, versi 1.0 tahun 2024; panel, tombol, slider dan elemen antarmuka | CC0 pada listing pembuat; HTML dan preview resmi tersimpan | Preview memperlihatkan panel kertas/blueprint dan bingkai logam. Bisa menjadi bahan identitas antarmuka game; beberapa varian terasa petualangan sehingga perlu seleksi. Paket gambar, bukan sistem layout atau logic. |
| [Kenney Fantasy UI Borders](https://kenney.nl/assets/fantasy-ui-borders) | Listing 140 file, versi 1.0 tahun 2023; border panel/tombol dekoratif | CC0 pada listing pembuat; HTML dan preview resmi tersimpan | Bingkai tipis bisa menjadi referensi, tetapi estetika fantasi/pixel dan tambahan ornamen belum tentu sesuai game pemerintahan. Bukan paket UI fungsional lengkap. |
| [Maaack Godot Game Template](https://github.com/Maaack/Godot-Game-Template) | Main menu, options, pause, credits, scene loader; README menyatakan Godot 4.7 / kompatibel 4.4+ | MIT; repository dan lisensi diperiksa lewat web. Cache API lokal gagal verifikasi sertifikat | Referensi struktur menu/fungsi, bukan solusi identitas visual. Proyek sudah punya save/settings/menu sendiri; penggantian menyeluruh berpotensi menduplikasi sistem. Belum diimpor atau diuji. |

Angka file Kenney berasal dari listing, bukan hasil menghitung isi arsip. Tidak ada library yang terpilih untuk produksi. Tidak mengeksekusi kode pihak ketiga, mengambil asset berbayar, atau menyalin UI game lain. [Katalog sumber](../sources/ui_library_review_2026-11-20.json), [catatan pengambilan dan checksum](../sources/ui_library_review_2026-11-20/capture.json), serta preview asli disimpan sebagai bahan review. Preview asli yang berhasil dilihat: [Themey/Spacey](../sources/ui_library_review_2026-11-20/raw/themey-screenshot.png), [Adventure](../sources/ui_library_review_2026-11-20/raw/ui-pack-adventure-preview.png), [Fantasy Borders](../sources/ui_library_review_2026-11-20/raw/fantasy-ui-borders-preview.png).

## Verifikasi, kegagalan, dan batas audit

- Berhasil: capture 13 keadaan runtime; inventaris teks/ukuran; hash world identik; verifikasi sumber pembuat dan pemisahan lisensi gambar/kode. Driver audit selesai dengan exit 0.
- Percobaan driver pertama gagal karena referensi autoload `Game` dari script di luar project; driver diganti dengan `root.get_node("Game")` lalu berhasil. Tidak memerlukan perubahan source produksi.
- Cache preview Clashy dan metadata API Maaack gagal karena validasi sertifikat TLS pada jalur Python. Kegagalan dicatat; validasi sertifikat tidak dinonaktifkan. README Themey dipin berhasil disimpan melalui jalur raw. Tidak menganggap preview Clashy sudah dilihat.
- Tidak dilakukan: redesign, pemasangan paket, pembaruan Figma, penggantian aset, tes regresi gameplay baru, tes pengguna manusia, pengukuran rasio kontras, audit 110% teks, dan QA mouse/keyboard menyeluruh. Pemeriksaan tombol muat di viewport pada QA lama tidak mengukur kepadatan atau keterbacaan.
- Laporan kuartal hanya keadaan awal yang belum berisi hasil. Kasus lain, teks panjang follow-up, data kebijakan aktif, detail pulau/nasional, overlay analitis, dan sesi permainan panjang belum dicakup audit runtime ini. Screenshot profil/pengaturan/laporan tetap disimpan meski tidak semuanya ditampilkan dalam laporan.

Urutan tindak lanjut yang disarankan untuk review Galih/Cleo: keterbacaan dan pembagian ruang → prioritas informasi per tugas → pengurangan pengulangan/lapisan → pemilihan satu bahasa visual dari referensi nyata. Tidak ada keputusan implementasi baru yang ditetapkan melalui laporan ini.

Reproduksi dari root repository (jendela Godot diperlukan):

```powershell
& '.\tools\godot\Godot_v4.7-stable_win64_console.exe' --path '.\game' --windowed -s 'D:\GameSimulator\research\reports\ui_audit_20261120\audit_current_ui.gd' -- --qa-audit=1
python 'research/sources/ui_library_review_2026-11-20/capture_sources.py'
```

Driver memakai path workspace `D:/GameSimulator` dan menimpa hanya hasil audit pada direktori evidence yang sama saat dijalankan ulang. Payload sumber yang sudah ada dipakai kembali oleh script capture.
