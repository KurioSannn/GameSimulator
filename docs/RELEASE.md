# Rilis dan pembaruan NUSANTARA

Panduan untuk tim: membuat file unduhan (Windows, macOS, Android) dan mengirim pembaruan yang terpasang otomatis di perangkat pemain (D-096).

## Ringkasan

| Platform | File | Cara pasang |
|---|---|---|
| Windows 10/11 (64-bit) | `NUSANTARA-<versi>-windows.exe` | Satu file, langsung dijalankan. Tidak perlu instal. |
| macOS 11+ (Apple Silicon dan Intel) | `NUSANTARA-<versi>-macos.zip` | Ekstrak, pindahkan `NUSANTARA.app` ke Applications. |
| Android 7+ (ponsel dan tablet) | `NUSANTARA-<versi>-android.apk` | Buka file APK di perangkat, izinkan "pasang dari sumber ini". |

iPhone dan iPad belum didukung: build iOS butuh Xcode dan akun Apple Developer.

## Membuat rilis penuh

```sh
scripts/release/build_release.sh 1.0.0
```

Hasilnya ada di `build/releases/1.0.0/`:
- tiga file unduhan di atas;
- `update.json`, manifest yang dibaca game;
- `base_*.pck`, paket dasar. **Simpan dan jangan diunggah.** File ini dibutuhkan untuk membuat pembaruan kecil berikutnya.

APK ditandatangani dengan kunci rilis di `~/.nusantara/` (di luar repo). **Cadangkan folder itu.** Tanpa kunci yang sama, pembaruan APK berikutnya tidak bisa dipasang di atas versi lama.

## Pembaruan kecil (cerita, data, keseimbangan, skrip)

```sh
scripts/release/build_release.sh 1.0.1 --patch 1.0.0
```

Perintah ini menghasilkan `patch-1.0.1-<platform>.pck`, yang hanya berisi file yang berubah (bisa beberapa KB saja), plus `update.json` baru.

Di perangkat pemain, alurnya:
1. Saat dibuka, game membaca manifest.
2. Paket pembaruan diunduh di latar belakang dan SHA-256-nya diperiksa.
3. Pemain melihat "Pembaruan siap". Di desktop ada tombol Mulai ulang. Di Android, pembaruan dipakai saat aplikasi dibuka lagi.

Simpanan permainan tidak tersentuh.

## Pembaruan besar (versi mesin atau aplikasi baru)

Naikkan versi minor atau mayor (mis. 1.1.0) dan buat rilis penuh. Game versi lama akan menampilkan "Versi baru tersedia" dengan tombol Unduh ke file untuk platform pemain. Aplikasi yang sedang berjalan tidak bisa mengganti installer-nya sendiri, jadi langkah ini butuh satu ketukan dari pemain.

## Menerbitkan

1. Buat GitHub Release dengan tag `v<versi>` di repo yang tercantum di `game/data/update_config.json`.
2. Unggah semua file di `build/releases/<versi>/` **kecuali** `base_*.pck`.
3. Karena game membaca `releases/latest/download/update.json`, rilis terbaru otomatis menjadi sumber pembaruan.

Repo atau server lain bisa dipakai dengan mengubah `manifest_url`, plus `NUSANTARA_RELEASE_BASE` saat build.

## Uji lokal

Jalankan server lokal di folder rilis, lalu buka game dengan:

```
NUSANTARA_UPDATE_URL=http://127.0.0.1:8765/update.json
```

Uji 2026-11-24: aplikasi macOS 1.0.0 mengunduh, memverifikasi, dan memuat patch 1.0.1 (1.980 byte).

## Peringatan yang diketahui

- **Windows SmartScreen** dan **macOS Gatekeeper** akan memperingatkan karena aplikasi belum ditandatangani dengan sertifikat berbayar. Di macOS: klik kanan, Buka. Di Windows: Info lainnya, Tetap jalankan. Sertifikat code signing (Windows) dan Apple Developer ID plus notarization (macOS) menghilangkan peringatan ini.
- Ikon file `.exe` di Explorer masih ikon Godot. Ikon jendela dan aplikasi sudah ikon NUSANTARA. Mengganti ikon exe dari macOS butuh `rcedit` lewat Wine.
- Patch tidak bisa mengubah `updater.gd` itu sendiri (sudah dimuat sebelum patch dipasang). Perubahan pada updater dikirim lewat rilis penuh.
