# Implementasi UI game NUSANTARA

Tanggal: 20 November 2026, Asia/Bangkok. Lingkup: antarmuka Godot; isi peta dikerjakan agent lain.

## Perubahan yang diterapkan

Arahan pengguna: implementasikan audit, gunakan elemen game, hilangkan keterangan APBN/simulasi yang mengganggu, besarkan teks, dan kurangi informasi yang harus dibaca saat bermain.

- HUD awal berisi tiga resource: kesejahteraan, kepercayaan, dan anggaran. Nama indikator tersedia melalui tooltip; indikator lainnya tetap ada di Statistik/Data. Satu agenda muncul di bawah dengan satu tindakan utama yang sesuai keadaan.
- Navigasi memakai tombol ikon heksagon; menu memakai medali; jendela memakai kertas dengan sudut logam, tombol bertekstur, dan banner. Semua dibangun dengan kontrol native Godot dan sprite asli Kenney, bukan gambar UI generatif.
- Menu utama menampilkan peta game yang berjalan. Gambar hero statis sebelumnya tidak lagi menutupi peta.
- Detail Wilayah menampilkan dua indikator awal dan mengikuti tinggi isi. Aktivitas, indikator lengkap, identitas administratif, penyebab, fakta resmi, dan sumber dibuka melalui tab. Panel tetap berlaku untuk kab/kota, provinsi, kelompok pulau, dan nasional.
- Keputusan memakai daftar opsi dan biaya di kiri. Manfaat, risiko, dan sasaran ditampilkan untuk **opsi yang sedang dipilih** di kanan. Pilihan belum dieksekusi sampai pemain menekan Tetapkan/Enter. Saat belum memilih, peta wilayah terdampak mengisi panel kanan.
- Pengantar kasus berupa kalimat awal narasi yang sudah ada, setelah pembuka meta dihilangkan; pratinjau dibatasi dua baris. Fakta sejarah, sumber, narasi lengkap, dan alasan follow-up tetap tersedia lewat Laporan lengkap. Tidak ada perubahan angka, efek, kondisi, atau teks sumber dalam dataset kasus.
- Label APBN, peringatan simulasi berulang, statistik waktu eksekusi, agenda duplikat, dan ringkasan kosong dikeluarkan dari alur normal sesuai permintaan pengguna. Metadata dan status sumber tetap tersimpan dalam lapisan data.
- HUD/drawer belakang disembunyikan ketika dialog aktif. Penutupan dialog mengembalikan konteks sebelumnya. Anggaran dan program memiliki tindakan yang tetap terjangkau; laporan dan alat peta dapat digulir ketika isinya panjang.

## Tipografi final

Hanya dua keluarga font aktif:

| Peran | Font | Penggunaan |
|---|---|---|
| Judul utama | Bree Serif Regular | Banner kasus, judul halaman, nama wilayah |
| Teks dan kontrol | Alegreya Sans Medium / Bold | Narasi, tombol, opsi, label, dan angka resource |

Font body diikat langsung pada label dan kelas kontrol, sehingga tidak jatuh ke font bawaan engine. Angka memakai bobot tebal dari keluarga utama. Font dekoratif dari percobaan sebelumnya dinonaktifkan dan dipindahkan ke cache riset.

Ukuran minimum teks helper adalah 22 pada canvas desktop 1440×810, sekitar 19,6 piksel keluaran pada 1280×720 sebelum pembesaran 110%. Judul dialog memakai 32. Ini ukuran font efektif, bukan pengukuran tinggi glyph atau sertifikasi aksesibilitas. Panel, footer, dan teks panjang diperiksa kembali setelah pembesaran.

## Hasil pengukuran

Perbandingan keadaan awal yang sama pada 1600×900, memakai metode inventaris kontrol audit sebelumnya:

| Keadaan | Blok teks sebelum | Blok teks sesudah | Kata sebelum | Kata sesudah |
|---|---:|---:|---:|---:|
| Peta awal | 49 | 10 | 121 | 26 |
| Detail kota + HUD | 81 | 19 | 198 | 38 |
| Detail provinsi + HUD | 79 | 19 | 189 | 38 |
| Keputusan, belum memilih | 48 | 15 | 246 | 38 |

Pada keputusan, pengurangan ini berasal dari penyajian bertahap. Rincian pilihan dan laporan tetap dapat dibuka. Jumlah kata adalah hitungan teks kontrol dan menjadi batas atas jika kontrol terpotong; bukan hasil OCR atau pengukuran beban kognitif. Inventaris juga tidak menghitung tulisan yang digambar langsung oleh peta/grafik. Tidak ditemukan kandidat tumpang tindih kotak teks pada 13 screenshot final yang diukur.

## Aset, sumber, dan reproduksi

- 24 PNG asli resolusi ganda dari **Kenney UI Pack – Adventure 1.1**, CC0. Listing pembuat masih menyebut versi 1.0; lisensi di arsip menyebut 1.1. Arsip berasal dari unggahan Kenney di OpenGameArt, bukan mirror tanpa identitas.
- Font dari repositori resmi Google Fonts pada revision `cc5661d43cd4f9aad5567033a8e15ca28dc35c86`, SIL OFL. Biner asli, pemberitahuan lisensi, URL, waktu pengambilan, dan SHA-256 disimpan.
- [Manifest aset UI](../../game/assets/ui/kenney_adventure/manifest.json), [manifest font aktif](../../game/assets/fonts/game_ui_manifest.json), [script bundling](../sources/ui_library_review_2026-11-20/bundle_game_ui.py), dan [katalog riset](../sources/ui_library_review_2026-11-20.json).
- Runtime tetap offline. Tidak memasang framework menu baru, mengeksekusi kode repository pihak ketiga, mengubah renderer peta, atau memodifikasi data simulasi.

## Verifikasi dan bukti

- Regresi headless: **154/154 tes lolos**, termasuk verifikasi font yang benar-benar terikat pada kontrol dan batas minimum font body.
- QA tambahan: **318 pemeriksaan lolos**, 27 kasus, seluruh pilihan pada 100%/110%, delapan program, tab lintas enam konteks geografis, dan sambungan kontrol waktu/cuaca yang sudah ada. Hash world/RNG sebelum dan sesudah pembacaan UI/pratinjau sama.
- QA alur mouse/keyboard dan aset: **128/128 pemeriksaan lolos**, tanpa runtime error. Mencakup pilih-lalu-konfirmasi, manfaat/risiko sebelum konfirmasi, sumber, anggaran, target program, simpan/muat terisolasi, laporan terisi, pengaturan 100%/110%, dan jendela 1280/1920.
- [Inventaris final](ui_implementation_20261120/final/inventory.json), [QA alur](ui_implementation_20261120/flow/qa_ui.json), [QA kasus/program](ui_implementation_20261120/clarity/qa.json), [driver inventaris](ui_implementation_20261120/audit_ui.gd), [driver tambahan](ui_implementation_20261120/verify_clarity.gd).
- Preview: [peta](ui_implementation_20261120/final/01_map_1600.png), [detail wilayah](ui_implementation_20261120/final/08_region_1280.png), [keputusan awal](ui_implementation_20261120/final/09_case_1280.png), [keputusan dipilih](ui_implementation_20261120/flow/case_selected_1280.png), [menu dengan peta hidup](ui_implementation_20261120/clarity/menu_live_3d_1280.png).

Kegagalan yang ditangani: label body sempat memakai font bawaan; asumsi nama keluarga font tidak memasukkan nama style; kasus terpanjang melebihi tinggi dialog pada 110%; tooltip dapat tertinggal di atas drawer; dan angka biaya sempat membungkus per karakter. Binding font dibuat eksplisit, ruang dialog dihitung dari minimum kontrol, posisi tooltip dibatasi, dan kolom angka diberi ruang horizontal. Pemeriksaan angka satu baris ditambahkan pada QA.

Tidak dilakukan: perubahan Figma, penggantian isi peta, perubahan mekanik, benchmark grafis ulang, sertifikasi kontras, atau pengujian pemain manusia. Tes headless masih mengeluarkan peringatan cleanup dua CanvasItem dan lima ObjectDB yang juga muncul sebelum perubahan font; tidak tercatat sebagai runtime error pada QA jendela. Penilaian akhir arah seni tetap memerlukan review manusia.

Reproduksi dari root repository:

```powershell
& '.\tools\godot\Godot_v4.7-stable_win64_console.exe' --headless --path '.\game' -s res://tests/run_tests.gd
& '.\tools\godot\Godot_v4.7-stable_win64_console.exe' --path '.\game' --windowed -- --qa-ui=D:/GameSimulator/research/reports/ui_implementation_20261120/flow
& '.\tools\godot\Godot_v4.7-stable_win64_console.exe' --path '.\game' --windowed -s D:/GameSimulator/research/reports/ui_implementation_20261120/verify_clarity.gd -- --qa-clarity=1
```

QA menulis hanya ke direktori evidence/save/pengaturan terisolasi miliknya. Launcher normal tetap `Mainkan NUSANTARA.cmd`.
