# Audit dan perbaikan UI Figma NUSANTARA, 15 November 2026

Audit ini memperbaiki tujuh layar NUSANTARA langsung pada [file Game Simulator](https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=15-16673). Perubahan terbatas pada desain dan koneksi prototipe Figma. Kode Godot, data resmi, parameter simulasi, dan angka contoh yang sudah ada tidak diubah.

## Lingkup dan dasar

Permintaan: bertindak sebagai front end UI, mengaudit dan memperbaiki desain yang ditautkan pengguna. Acuan: `CLAUDE.md`, `AGENTS.md`, `docs/22_UI_UX_SPEC.md`, `STATUS.md`, `DECISIONS.md`, `game/src/ui/hud.gd`, `game/src/ui/stitch_theme.gd`, `game/data/ui/stitch_tokens.json`, serta penanganan tombol di `game/src/app/main.gd`.

Layar yang diaudit: menu awal, beranda/peta, profil presiden, statistik, pengaturan, peristiwa/keputusan, dan laporan kuartal. Seluruh frame utama tetap 1920 × 1080. Identitas Nara Adinata, ilustrasi existing, keluarga font Lilita One dan Inter, serta palet biru–ungu–kuning dipertahankan. “THE MANDATE” tetap sebagai nama/subjudul produk yang tercantum pada README, bukan teks alur berbahasa Inggris yang baru.

Sebelum perubahan, ketujuh layar disalin ke halaman **Arsip UI • sebelum audit 15 Nov 2026** (page `51:16724`). Frame produksi diperbaiki di tempat sehingga ID utama tetap sama.

## Temuan dan hasil

| Prioritas | Temuan | Perbaikan |
|---|---|---|
| P1 | Form email/kata sandi dan pendaftaran tidak selaras dengan kontrak luring. | Diganti menu awal dengan Mulai Mandat Baru, Cara Bermain, penjelasan simpanan lokal dan durasi mandat. Ditambahkan panduan singkat sebagai overlay. |
| P1 | Pekan dan kecepatan 1×/2×/3× mengisyaratkan waktu nyata, sementara model memiliki tick bulanan dan giliran kuartalan. | Label kuartal/tahun dan 3 bulan per giliran; sumbu grafik menjadi bulanan; SPASI dijelaskan sebagai Lanjut kuartal sesuai kode existing. Tidak ada referensi “pekan” pada teks terlihat di tujuh layar setelah koreksi. |
| P1 | Kartu A berbeda sendiri: biru sangat terang, kotak hijau/merah, bidang berlabel kata sandi, biaya dekoratif, dan potensi tumpang tindih. | Susunan manfaat, risiko, harga, kilau kartu dan status seleksi disamakan dengan B/C. Reaksi dan binding pilihan A dipertahankan. |
| P1 | Laporan angka kuartal merupakan contoh opsi B; menghubungkannya ke semua pilihan akan mengarang konsekuensi A/C. | Laporan lengkap hanya dicapai ketika B sudah dikonfirmasi. A/C menggunakan panel konsekuensi dinamis existing. Pilihan yang belum dikonfirmasi menampilkan peringatan. |
| P1 | Angka contoh pada beranda/profil/statistik belum ditandai secara merata. | Ditambahkan instance penanda contoh simulasi; header kasus menyebut nilai rekaan. Penanda laporan diperjelas. Tidak ada angka contoh yang dipromosikan menjadi statistik resmi. |
| P2 | Layar profil berjudul Statistik Pemerintahan dan justru menandai tab Statistik aktif. | Judul menjadi Profil Presiden; tab Profil aktif; navigasi Profil–Statistik dan kembali ke peta ditambahkan. |
| P2 | Keterangan penting berukuran 10–13 px dan tipografi kartu A tidak konsisten. | Label HUD, keterangan pengaturan, sumbu grafik, manfaat/risiko, dan delta laporan diperbesar sesuai ruang. Teks isi yang diperbaiki menggunakan Inter; stroke hitam pada teks isi A dihapus. |
| P2 | Tautan antarlayar tidak lengkap dan pilihan kurang terlihat sebelum penetapan. | Menu awal–peta, peta–kasus, profil/statistik, pengaturan/kembali, panduan, dan laporan/peta dihubungkan. Footer kasus menampilkan ringkasan pilihan terikat variabel serta penjelasan bahwa memilih belum menetapkan keputusan. |

## Struktur desain

Tidak ditemukan library terpasang atau hasil pencarian aset NUSANTARA yang cocok. Karena itu fondasi kecil dibangun dari token warna existing di `stitch_tokens.json`, bukan mengimpor UI mobile atau library yang tidak sesuai.

- Penanda simulasi dengan properti teks dipakai pada lima lokasi, termasuk varian teks luring di menu.
- Keluarga tombol menu memiliki empat varian: Utama/Sekunder × Normal/Fokus. Fokus dibedakan dengan garis putih 4 px.
- Sembilan belas variabel: delapan warna dasar, delapan alias semantik, tiga ukuran; scope ditetapkan eksplisit.
- Tiga text style: Isi, Label, Tombol.
- Menu dan panduan menggunakan auto layout; struktur existing lain tidak dibangun ulang seluruhnya.
- Warna fallback di paint diselaraskan dengan nilai token setelah inspeksi screenshot menemukan teks gelap pada beberapa node.

Komponen lokal: [papan komponen](https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=53-16749). Panduan: node `53:16773`. Inventaris ID, jumlah node tiap tipe, daftar image fill, dan cabang reaksi tersimpan dalam `2026-11-15_FIGMA_UI_AUDIT_EVIDENCE.json`.

## Verifikasi

- Tujuh layar diperiksa lewat screenshot komposisi pada render 1440 px; screenshot ulang dilakukan setelah koreksi visual pada layar terkait. Papan komponen dan panduan juga diperiksa.
- Font dibaca ulang dan cocok dengan sumber existing: Lilita One dan Inter.
- Pemeriksaan geometri teks terlihat tidak menemukan teks keluar dari batas parent pada subset yang diperiksa. Group/instance dan layer peta latar kasus dikecualikan dari pemeriksaan geometri sederhana; screenshot digunakan untuk menilai komposisi.
- Teks, tombol, panel, dan hierarki tetap editable. Image fill hanya berupa ilustrasi latar/karakter, potret, avatar dan seni peta existing; tidak ditambahkan raster dari keseluruhan UI.
- Evaluasi statis terhadap reaksi yang dibaca ulang: **6/6 lulus**, A/B/C setelah konfirmasi dan A/B/C sebelum konfirmasi. B terkonfirmasi menuju laporan B; A/C menuju konsekuensi dinamis; ketiganya sebelum konfirmasi menuju peringatan.
- Evaluasi tersebut bukan playback interaktif di browser. Tidak dijalankan test engine karena tidak ada perubahan runtime.
- Selama validasi ditemukan bahwa representasi kondisi yang diterima tool tidak mempertahankan tiga cabang seperti yang diharapkan. Guard diperbaiki menjadi tiga aksi kondisional terpisah dan dibaca ulang; pengujian di atas memakai hasil baca ulang, bukan hanya skrip yang dikirim.

## Yang gagal atau dilewati

- Unduhan screenshot melalui shell gagal karena koneksi jaringan sandbox; inspeksi menggunakan gambar inline dari Figma MCP.
- `Variable.setCodeSyntax` tidak tersedia pada API koneksi ini. Code syntax dilewati; alias, scope, binding dan nilai warna tetap diterapkan. Ini bukan klaim adanya sinkronisasi otomatis dengan Godot.
- Tidak ada generasi aset/gambar baru atau konsumsi kredit Figma AI untuk gambar. Aset existing dipakai kembali.
- Tidak mengubah scene/script Godot, menambah statistik resmi, mengkalibrasi konsekuensi, mengurangi cakupan wilayah simulasi, atau menulis ulang frame referensi Brawler/Spongebob di luar layar NUSANTARA.

## Kesenjangan yang masih ada

1. Perbaikan Figma belum diintegrasikan ke Godot. Font runtime masih perlu dicocokkan dengan aset font yang tersedia dan lisensinya.
2. Pengaturan audio/tampilan, pemetaan tombol, edit profil, simpan/muat dan persistensi masih memerlukan implementasi/QA runtime; reaksi navigasi Figma tidak membuktikan fitur tersebut bekerja.
3. Seni peta yang ada merupakan referensi visual kasar. Interaksi provinsi/kabupaten/kota, hover, zoom dan sumber wilayah harus menggunakan pipeline geografi resmi existing, bukan gambar ini sebagai data.
4. Pusat Data dan panel sumber lengkap belum dirancang pada audit ini. Mockup yang belum memuat data resmi tidak boleh mengarang sumber, tanggal atau nilai.
5. Banyak layout existing masih berposisi absolut; kelulusan screenshot tidak membuktikan perilaku resize window, navigasi keyboard penuh, pembaca layar atau skala teks 150%.
6. Laporan kuartal lengkap masih satu fixture ilustratif B. Produksi perlu menghasilkan laporan dari ledger simulasi untuk semua pilihan, bukan menduplikasi angka fixture.

Langkah berikutnya: Galih meninjau perubahan desain dan mengintegrasikan komponen/label ke presentasi Godot; Cleo/Ananda meninjau konsistensi aset. Prioritas integrasi adalah menu luring, indikator periode, status data dan guard keputusan, lalu panel wilayah/Pusat Data dan QA ukuran jendela.

## Provenance audit

| Field | Nilai |
|---|---|
| Source institution | Tim NUSANTARA / file Figma yang ditautkan pengguna |
| Title | Game Simulator; spesifikasi UI/UX dan kontrak proyek NUSANTARA |
| URL | https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=0-1 |
| Publication/update date | Tanggal publikasi sumber awal tidak tersedia; perubahan audit dilakukan 2026-11-15 |
| Retrieval timestamp | 2026-11-15T01:45:47Z |
| Geographic resolution | UI nasional dan ilustrasi wilayah; bukan dataset administratif atau pengukuran wilayah |
| Reference year/period | Snapshot audit 2026-11-15; periode permainan pada mockup bersifat ilustratif |
| Unit | Piksel, jumlah node/layar, label periode, hasil evaluasi cabang prototipe |
| Source status | Prototipe internal + dokumen proyek; bukan statistik resmi |
