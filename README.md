# NUSANTARA: Lima Tahun Menjaga Negeri

> **Karya Lomba IT-Competition AMIKOM Surakarta (IT-CAS) 2026 — Kategori Game Development (Mahasiswa)**  
> **Tema:** *“Inovasi Cerdas & Kearifan Lokal untuk Indonesia Emas”*

---

## Ringkasan Permainan

**NUSANTARA** adalah gim simulasi tata kelola pemerintahan dan strategi berbasis data nyata Indonesia (*offline-first*). Pemain berperan sebagai **Presiden Nara Adinata** (tokoh fiktif) yang memimpin Indonesia selama satu masa bakti lima tahun (20 kuartal) di tengah tantangan bencana, ketahanan pangan, ekonomi, lingkungan, dan keragaman budaya.

Berbeda dari simulasi abstrak pada umumnya, peta dan kondisi awal **NUSANTARA** memodelkan **38 provinsi dan 514 kabupaten/kota Indonesia secara individual**, lengkap dengan **50 studi kasus nyata** yang diadaptasi dari peristiwa faktual serta **kearifan lokal Nusantara** (seperti *Subak*, *Sasi*, *Awig-awig*, *Panglima Laot*, dan pengelolaan hutan adat).

> **Alur Permainan Inti:**  
> `Amati Peta & Data` → `Pahami Kasus` → `Tetapkan Keputusan` → `Alokasi Anggaran & Kebijakan` → `Simulasi Kuartal (514 Daerah)` → `Evaluasi & Warisan`

---

## Tautan Unduhan Resmi (v1.0.2)

Seluruh build bersifat mandiri (*standalone*) dan **dapat langsung dimainkan tanpa instalasi perangkat lunak tambahan**:

| Platform | Berkas Unduhan | Ukuran | Batas Ketentuan IT-CAS |
| :--- | :--- | :--- | :--- |
| **Windows (10/11 64-bit)** | [NUSANTARA-1.0.2-windows.exe](https://github.com/KurioSannn/GameSimulator/releases/download/v1.0.2-windows/NUSANTARA-1.0.2-windows.exe) | ~217 MB | Maks 1 GB (Memenuhi) |
| **Android (7.0+ Mobile/Tablet)** | [NUSANTARA-1.0.2-android.apk](https://github.com/KurioSannn/GameSimulator/releases/download/v1.0.2-mobile/NUSANTARA-1.0.2-android.apk) | ~150 MB | Maks 250 MB (Memenuhi) |
| **macOS (Apple Silicon & Intel)** | [NUSANTARA-1.0.2-macos.zip](https://github.com/KurioSannn/GameSimulator/releases/download/v1.0.2-macos/NUSANTARA-1.0.2-macos.zip) | ~123 MB | Bonus Multiplatform |
| **Panduan Bermain (PDF)** | [Panduan_Bermain_NUSANTARA.pdf](./Panduan_Bermain_NUSANTARA.pdf) | PDF | Wajib Sesuai Ketentuan |

> **Catatan Keamanan OS:**  
> - **Windows SmartScreen:** Jika muncul peringatan aplikasi tidak dikenal, klik **More info** lalu **Run anyway**.  
> - **Android:** Izinkan opsi *"Pasang aplikasi dari sumber ini"* saat membuka berkas `.apk`.  
> - **Auto-Updater:** Game dilengkapi sistem pembaruan otomatis (*in-game patch*) melalui [manifest rilis terbaru](https://github.com/KurioSannn/GameSimulator/releases/latest/download/update.json).

---

## Kesesuaian dengan Tema IT-CAS 2026

1. **Inovasi Cerdas:** Simulasi deterministik yang menghitung dinamika sosial, ekonomi, harga pangan, kepercayaan publik, dan dampak lingkungan di **514 kabupaten/kota secara bersamaan** setiap kuartal berdasarkan data publik resmi (BPS, BIG, Kemendagri, BNPB, BMKG).
2. **Kearifan Lokal untuk Indonesia Emas:** Mengangkat nilai gotong royong dan kearifan lokal spesifik daerah sebagai opsi kebijakan strategis yang memiliki konsekuensi terukur terhadap keberlanjutan wilayah.
3. **Nilai Edukatif & Transparansi Data:** Pemain dapat meninjau sumber data asli di dalam gim (*Mode Pengembang / Sumber Data*), memahami *trade-off* kebijakan fiskal, serta melihat bagaimana keputusan jangka pendek memengaruhi warisan bangsa jangka panjang.

---

## Cara Bermain Singkat

Lihat panduan lengkap bergambar di berkas **[Panduan_Bermain_NUSANTARA.pdf](./Panduan_Bermain_NUSANTARA.pdf)**.

1. **Mulai Mandat:** Buka game, klik **MULAI PEMERINTAHAN BARU** (atau **LANJUTKAN** untuk memuat simpanan terakhir).
2. **Eksplorasi Peta:** Klik provinsi atau kabupaten/kota pada peta 3D/2D Nusantara untuk membaca kondisi ekonomi, risiko bencana, dan sentimen daerah.
3. **Tangani Kasus:** Setiap kuartal akan muncul kasus nasional atau daerah. Pelajari opsi yang tersedia, perhatikan dampaknya, lalu klik **Tetapkan Keputusan**.
4. **Atur Kebijakan & Anggaran:** Gunakan panel **Kebijakan (`P`)** dan **Anggaran (`B`)** untuk menjaga stabilitas fiskal dan melindungi wilayah rawan.
5. **Lanjut Kuartal (`Spasi`):** Jalankan simulasi 3 bulan sekaligus untuk seluruh 514 daerah dan pantau hasilnya di **Laporan Kuartal** hingga akhir tahun ke-5 (**Rapor Warisan**).

### Kontrol Utama
- **Geser Peta:** Seret Klik Kiri / `WASD` / Tombol Panah / Usap Layar (Mobile)
- **Zoom:** Scroll Mouse / Cubit (*Pinch*) / Tombol `+` & `−` / `Home` (Reset Seluruh Indonesia)
- **Putar Peta 3D:** Tahan Klik Kanan atau `Q` / `E`
- **Pintasan Cepat:** `Spasi` (Lanjut Kuartal) · `P` (Kebijakan) · `B` (Anggaran) · `F5` (Simpan Cepat) · `F9` (Muat Cepat) · `Esc` (Tutup Panel)
- **Keluar Permainan:** Klik tombol **KELUAR** di Menu Utama atau melalui menu **`☰` → Keluar** (progres disimpan otomatis).

---

## Teknologi & Tools yang Digunakan

| Kategori | Teknologi / Tools | Kegunaan |
| :--- | :--- | :--- |
| **Game Engine** | Godot Engine 4.7 | Engine utama untuk rendering peta 3D/2D, UI, audio, dan ekspor lintas platform (`.exe`, `.apk`, `.zip`) |
| **Bahasa Pemrograman** | GDScript | Logika simulasi deterministik, manajemen kasus/cerita, UI reaktif, dan pengujian otomatis (184 unit/integration tests) |
| **Pengolahan Data & GIS** | Python | Pemrosesan data spasial GeoJSON/Shapefile (BIG & Kemendagri) dan normalisasi data statistik (BPS, BNPB, BMKG) |
| **Desain UI & Aset Visual** | Figma, Aset CC0 (Kenney), Google Fonts | Perancangan antarmuka, ikonografi, model 3D dekorasi peta, serta tipografi |
| **Kolaborasi & Rilis** | Git & GitHub Releases | Manajemen versi kode sumber dan distribusi installer serta patch otomatis |

---

## Tim Pengembang (3 Anggota)

- **Galih** — Game Director, Integrasi Teknis, Pemrograman Simulasi & Engine
- **Ananda** — Desain Karakter & Aset Visual
- **Cleo** — Desain Antarmuka (UI/UX), Aset Grafis & Tata Letak

---

## Pernyataan Penggunaan AI (Sesuai Ketentuan IT-CAS 2026)

Sesuai dengan ketentuan penggunaan AI pada panduan lomba **IT-CAS 2026**, tim kami mengungkapkan secara transparan bahwa perangkat AI generatif (**ChatGPT / Claude**) digunakan **sebatas sebagai alat bantu untuk *brainstorming*, riset awal, dan penyusunan ide** (seperti eksplorasi kerangka konsep tata kelola, pemetaan referensi publik resmi, serta perumusan variasi skenario edukatif).

Seluruh proses kreatif inti, penulisan dan arsitektur kode permainan, perancangan visual/UI, validasi data statistik resmi, serta keputusan desain akhir dikerjakan, diverifikasi, dan dipertanggungjawabkan sepenuhnya oleh anggota tim.

---

## Pengujian & Verifikasi (Untuk Pengembang)

Menjalankan seluruh *test suite* headless (184 pengujian simulasi, kasus, peta, tema UI, audio, dan simpanan):

```sh
tools/Godot.app/Contents/MacOS/Godot --headless --path game -s res://tests/run_tests.gd
```
