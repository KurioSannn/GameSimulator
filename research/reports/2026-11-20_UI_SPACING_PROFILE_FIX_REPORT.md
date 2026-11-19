# Perbaikan profil, avatar, dan jarak bingkai

Tanggal: 20 November 2026. Pengguna memberi izin implementasi setelah membaca audit melalui pesan “gas ganti”.

## Hasil

- Panel berbingkai memakai ruang isi 36 unit terhadap slice 24 unit. Tombol footer, tutup, dan laporan mendapat jarak yang konsisten dari ornamen pada kasus, anggaran, program, wilayah, dan sumber. Lebar scroll kasus kini dihitung dari margin frame sebenarnya.
- HUD identitas memakai frame kertas sederhana dengan ruang avatar sendiri. Portrait dibingkai dan dipotong sesuai rasio tujuan, tanpa meregangkan wajah. Helper yang sama dipakai pada profil dan rapor warisan.
- Ilustrasi profil dan bayangan kontak berada dalam satu komponen. Atlas memakai batas alpha ilustrasi asli; kaki mengikuti baseline bayangan pada setiap ukuran. Elips biru terpisah dihapus dari komposisi profil.
- Profil menggabungkan ringkasan mandat dan kepercayaan; nama/jabatan tokoh tidak diulang dalam kartu pemain. Font dan palet yang sudah dipilih tetap dipakai.
- Editor nama memiliki kolom yang jelas, Simpan Nama, Batal, status Belum disimpan / Nama tersimpan, dan Enter untuk menyimpan. Aksi nonaktif saat tidak ada perubahan; nama kosong disinkronkan menjadi Pemain pada kolom dan preferensi. Nama karakter tetap Nara Adinata.
- Tombol nonaktif memakai kertas redup dengan teks yang tetap terbaca, menggantikan abu-abu gelap sebelumnya.

## Bukti visual

- [Profil dan nama tersimpan](ui_spacing_fix_20261120/profile_name_saved_1600.png).
- [Profil 1280×720, teks 110%](ui_spacing_fix_20261120/profile_1280_110.png).
- [HUD identitas](ui_spacing_fix_20261120/hud_1920_100.png).
- [Kasus Sabu Raijua, teks 110%](ui_spacing_fix_20261120/CASE-0006_1280_110.png).
- [Panel wilayah](ui_spacing_fix_20261120/region_1280_110.png).

## Verifikasi

82 keadaan UI dan 42 screenshot final pada 1280×720 / 1920×1080, skala teks 100% / 110%. Tidak ditemukan kandidat tombol terlihat di luar area aman slice, panel, maupun viewport. Item scroll yang terpotong secara alami tetap dicatat terpisah. Ini pemeriksaan geometry konservatif, dilengkapi inspeksi screenshot; bukan sertifikasi mask piksel untuk setiap ornamen.

| Layar 1280×720, teks 100% | Kandidat area aman sebelum | Sesudah |
|---|---:|---:|
| HUD | 3 | 0 |
| CASE-0006 | 7 | 0 |
| Anggaran | 3 | 0 |
| Program | 1 | 0 |
| Wilayah | 4 | 0 |
| Sumber | 1 | 0 |

- Regresi headless: **155/155 tes lolos**. Tes baru memeriksa kontrak jarak frame, rasio avatar, dan kontak kaki/bayangan pada dua ukuran.
- QA profil/spacing: **20/20 observasi lolos**, termasuk simpan via tombol, buka ulang, Enter, trimming, nama kosong, batal, karakter tetap, grounding, serta serialisasi world/RNG yang identik sebelum/sesudah operasi UI.
- Preferensi dan save fixture diarahkan ke `.tmp/ui-spacing-fix-20261120/`; data pemain tidak dipakai untuk fixture.
- QA seluruh **27 kasus dan 8 program**: **318/318 pemeriksaan lolos**, mencakup semua pilihan pada teks 100%/110%, perubahan konteks wilayah, dan integrasi time/weather yang sudah ada. [Bukti](ui_spacing_fix_20261120/extended/qa.json).
- Alur mouse/keyboard, menu, keputusan, pengaturan, simpan/muat dan aset terlihat: **125/125 pemeriksaan lolos**, tanpa runtime error. Jumlah ini juga menghitung aset yang sedang terlihat; tidak dibandingkan sebagai jumlah skenario dengan versi profil lama. [Bukti](ui_spacing_fix_20261120/flow/qa_ui.json).

## Batas dan percobaan

Percobaan awal probe UI melewatkan klik simpan pertama setelah perubahan state/layout, sehingga tiga assertion nama gagal. Driver diperbaiki untuk menunggu reflow dan mengirim gerakan pointer sebelum menarget tombol. Verifikasi nama terpisah dan pengambilan 82 keadaan final kemudian berhasil. Bukti awal dipertahankan dalam `ui_spacing_fix_20261120/initial/`.

Percobaan Godot dalam sandbox gagal mengakses log/editor settings native dan runner headless berhenti sebelum tes. Eksekusi native yang mendapat izin berhasil. Peringatan cleanup dua CanvasItem RID dan lima ObjectDB pada akhir regresi headless juga sudah ada sebelum pekerjaan ini; suite jendela final tidak mencatat runtime error.

Tidak dilakukan: penggantian/pengunggahan avatar, pembuatan ilustrasi baru, perubahan Figma, perubahan renderer peta, perubahan geografi, perubahan simulation/save format, atau penambahan keluarga font. Tidak ada aset eksternal baru. Ultralebar dan DPI OS lain belum diuji; target Windows minimum tetap 1280×720.

## Implementasi dan reproduksi

- `game/src/ui/game_skin.gd`: kontrak frame/banner/selection/disabled style.
- `game/src/ui/hud.gd`, `figma_assets.gd`: identitas dan portrait bersama; integrasi time/weather yang sudah ada dipertahankan.
- `game/src/ui/president_portrait.gd`: ilustrasi dan kontak bayangan dalam satu ruang koordinat.
- `game/src/ui/player_name_editor.gd`: editor identitas perangkat, terpisah dari state simulasi.
- `game/src/ui/desktop_screens.gd`, `case_modal.gd`: komposisi profil dan perhitungan lebar isi.
- `game/tests/test_ui_theme.gd`: regresi kontrak UI.

Driver dan geometry: [verify_spacing.gd](ui_spacing_fix_20261120/verify_spacing.gd), [inventory.json](ui_spacing_fix_20261120/inventory.json), [summary.json](ui_spacing_fix_20261120/summary.json), [analyze_spacing.py](ui_spacing_fix_20261120/analyze_spacing.py). Provenance: [katalog lokal](../sources/ui_spacing_fix_2026-11-20.json).

```powershell
& tools/godot/Godot_v4.7-stable_win64_console.exe --headless --path game -s res://tests/run_tests.gd
& tools/godot/Godot_v4.7-stable_win64_console.exe --path game --windowed -s D:/GameSimulator/research/reports/ui_spacing_fix_20261120/verify_spacing.gd -- --qa-spacing-fix=1
python research/reports/ui_spacing_fix_20261120/analyze_spacing.py
```

Tindak lanjut: review hasil visual dalam permainan. Perubahan sudah diintegrasikan ke UI Godot.
