# Detail Wilayah umum: audit dan implementasi Figma

**Tanggal:** 15 November 2026.  
**Lingkup pengguna:** Detail Wilayah digunakan secara umum pada setiap konteks peta; Jawa Timur adalah contoh isi.

[Contoh provinsi, kota dan kelompok pulau](https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=65-17076) · [Main component](https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=65-16837) · [Layar contoh penggunaan](https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=57-16693).

## Hasil

Drawer khusus Jawa Timur diganti instance **Nusantara / Detail wilayah**, yang juga dipakai oleh overlay bersama. Main component tidak mempunyai default nama atau data Jawa Timur. Identitas, cakupan, indikator, data acuan, peristiwa, target kebijakan dan sumber menerima isian; Jawa Timur hanya satu fixture ilustratif existing.

Tiga komponen lokal dibuat memakai fondasi warna/font audit sebelumnya: Detail wilayah, Indikator wilayah, dan Baris sumber wilayah. Contoh memperlihatkan provinsi Jawa Timur, Kota Surabaya, dan kelompok pulau Sulawesi. Nama dan identitas administratif contoh dicek pada registry lokal; angka ilustratif tidak diperlakukan sebagai pengamatan resmi.

## Cakupan peta yang terhubung

| Konteks | Frame | Pemicu |
|---|---|---:|
| Peta nasional/beranda | `15:16673` | 15 |
| Peta kasus dan lokasi terdampak | `22:16673` | 19 |
| Peta dampak laporan kuartal | `24:16724` | 9 |
| Peta pada layar contoh Detail Wilayah | `57:16693` | 15 |
| Total | Empat konteks | 58 |

Pemicu mencakup nama wilayah, penanda, legenda laporan, peta lokasi kasus dan tombol data wilayah yang relevan. Semuanya membuka overlay yang sama dan mengisi ulang **38 field konteks terpilih**. Tutup/ESC pada overlay mengembalikan pengguna ke konteks asal; instance pada layar contoh memiliki aksi kembali ke beranda.

Label pulau/kelompok pulau tidak otomatis dianggap provinsi: misalnya Kalimantan, Sulawesi dan label geografis Papua. Penanda agenda Maluku memakai cakupan provinsi, sedangkan label geografis Maluku pada peta memakai Kepulauan Maluku. Nilai kabupaten/kota atau provinsi tidak diisi dari statistik tingkat lain.

## Perbaikan audit

- Label dan satuan indikator dipisahkan dari nilainya. Perubahan menggunakan poin; kepercayaan dijelaskan sebagai poin persentase.
- Acuan perubahan mengikuti konteks: awal mandat untuk contoh panel; awal kuartal untuk laporan. Acuan harga 100 berasal dari kontrak model existing, bukan IHK resmi.
- Bar indikator diganti keterangan skala/satuan pada komponen umum, sehingga indeks harga tidak terlihat dibatasi skor 100.
- Nilai contoh Jawa Timur dipertahankan pada konteks yang memakai fixture tersebut. Pada wilayah lain nilai dan perubahan direset menjadi `, `; data yang belum ada berstatus **Belum dimuat**.
- Peta laporan tidak mengambil indikator nasional sebagai indikator regional. Semua angka regional yang tidak tersedia pada fixture laporan tetap kosong, termasuk ketika Jawa Timur dipilih.
- Data acuan memiliki properti ringkasan dan status yang bisa diisi ulang. Tabel sumber menampilkan lembaga, judul, tautan, tanggal publikasi/pembaruan, waktu pengambilan, cakupan, periode, satuan dan status; informasi yang belum diketahui tetap kosong/Belum dimuat.
- Aksi Atur Kebijakan membuka konteks wilayah terpilih. Hanya fixture kasus Jawa Timur yang punya rincian opsi tertaut; wilayah lain tidak diarahkan ke kasus Jawa Timur.
- Baris metadata memakai tinggi mengikuti isi setelah screenshot menemukan tumpang tindih. Label tombol shared memakai FILL agar mengikuti lebar panel; menu awal sebelumnya diperiksa ulang setelah koreksi ini.

## Pelestarian

Sebelum perubahan, empat frame konteks disalin ke halaman arsip existing `51:16724`, dengan prefix **Sebelum panel wilayah umum**. Backup: `63:16706`, `63:17036`, `63:17504`, `63:17691`. Frame contoh `57:16693` dipertahankan ID-nya dan dinamai sebagai contoh penggunaan umum. Ilustrasi, geometri peta existing, model simulasi, parameter, dan dataset raw tidak diubah.

## Verifikasi

- **58/58** reaksi pemilihan yang dibaca ulang mengarah ke satu overlay dan mengisi seluruh 38 field.
- **6/6** urutan pergantian wilayah lintas konteks lulus: Jawa Timur/beranda → Maluku → Papua/laporan → Jawa Timur/laporan → Jawa Timur/kasus → Kalimantan/peta wilayah. Keadaan tidak mewarisi angka wilayah sebelumnya.
- Lima instance yang diperiksa memakai main component yang sama; properti default main component tidak memuat Jawa Timur.
- Screenshot diperiksa untuk layar contoh, tiga keadaan komponen, sumber, konteks kebijakan dan menu awal yang memakai tombol shared.
- Pemeriksaan akhir tidak menemukan teks terlihat keluar dari parent pada subtree yang diperiksa. Font tetap Lilita One dan Inter; UI berupa layer editable, tidak diratakan menjadi gambar.
- Evaluasi reaksi bersifat statis; bukan playback browser atau test engine.
- Bukti node, binding, field dan hasil pemeriksaan: `2026-11-15_REGION_DETAIL_UI_EVIDENCE.json`.

## Kegagalan dan batas

API menolak scope kosong untuk variabel BOOLEAN. Boolean visibilitas aksi kasus ditetapkan eksplisit ke ALL_SCOPES sebagai pengecualian kompatibilitas; variabel teks memakai TEXT_CONTENT. Beberapa permintaan baca/return perlu diperkecil karena batas keluaran tool; perubahan yang ditolak tidak dikomit. Temuan layout dari screenshot diperbaiki sebelum selesai.

Godot belum diubah. Pemilihan geometri seluruh kabupaten/kota, pan/zoom nyata, pengisian dari SimWorld/SimLedger, data sumber resmi, persistensi kebijakan dan QA resize masih pekerjaan integrasi. Cakupan 58 pemicu adalah cakupan prototipe Figma existing, bukan klaim bahwa semua poligon Indonesia sudah interaktif. Profil budaya dan indikator mendalam tambahan tidak diisi dengan konten rekaan.

Langkah berikutnya: integrasikan satu adapter data wilayah pada presentasi Godot menggunakan ID registry, resolution flag dan ledger simulasi. Semua sumber peta mengirim identitas wilayah/konteks ke panel yang sama. Hindari controller atau panel terpisah untuk setiap wilayah.

## Dasar dan provenance

Acuan internal: `CLAUDE.md`, `AGENTS.md`, `docs/22_UI_UX_SPEC.md`, `game/src/ui/region_panel.gd`, `game/data/sim_params.json`, `game/data/baseline.json`, `game/data/regions.json`, fondasi Figma audit sebelumnya dan frame Detail Wilayah yang ditunjuk pengguna.

| Field | Nilai |
|---|---|
| Source institution | Tim NUSANTARA; file desain yang diberikan pengguna |
| Title | Game Simulator / Detail Wilayah; kontrak UI dan model NUSANTARA |
| URL | https://www.figma.com/design/xXZj1Xnoxln1coG2yEO81a/Game-Simulator?node-id=57-16693 |
| Publication/update date | Tanggal awal frame tidak tersedia; perubahan audit 2026-11-15 |
| Retrieval timestamp | 2026-11-15T02:11:34Z |
| Geographic resolution | Provinsi, kota/kabupaten, kelompok pulau dibedakan; tidak membuat pengamatan statistik baru |
| Reference year/period | Snapshot audit 2026-11-15; nilai mockup bersifat ilustratif |
| Unit | Piksel, jumlah pemicu/node, field UI dan hasil evaluasi reaksi |
| Source status | Prototipe internal + registry/kontrak lokal; bukan publikasi statistik resmi |
