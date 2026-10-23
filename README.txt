TURBO DRIFT - game balap 3D realistis, Godot 4.3+ (renderer Mobile)
Mobil: Lamborghini Aventador LP 700-4 (V12 6.5L, 740 hp, 7 percepatan, AWD)

CARA JALANKAN
1. Buka Godot 4.3 atau lebih baru -> Import -> pilih project.godot -> Import & Edit.
2. Tekan F5.

KONTROL
- Sentuh: tombol < > (setir), GAS, REM, NITRO, ULANG (tegakkan mobil).
- Keyboard: A/D atau panah = setir, W = gas, S = rem/mundur, Spasi = rem tangan,
  Shift = nitro, R = ulang.
- DRIFT: tahan REM sambil belok saat kecepatan tinggi.

KUALITAS GRAFIS
- main.gd: RENDER_SCALE (1.7 = sangat tajam; turunkan ke 1.0 atau 0.8 kalau HP berat).
- project.godot: directional_shadow/size (4096 -> 2048), reflection_size (512 -> 256).

MODEL MOBIL ASLI
Untuk tampilan yang persis sama dengan mobil nyata, taruh file models/mobil.glb
(lihat models/LETAKKAN_MODEL_DI_SINI.txt). Tanpa file itu, game memakai bodi buatan kode.

EXPORT KE ANDROID
Editor -> Manage Export Templates (unduh), lalu Project -> Export -> Add -> Android.

=== BALAPAN, ONLINE, TOKO, MOBIL TERBANG ===
- Lobi: pilih/beli mobil di TOKO & GARASI (koin tersimpan otomatis). Menang balapan = koin.
- BALAPAN: 3 putaran lawan AI (atur jumlah lawan di tombol LAWAN AI).
- ONLINE: server khusus -> godot --headless --path . -- --server [--port=7777]
  (buka UDP 7777). Atau tekan BUAT RUANG di satu HP; teman GABUNG lewat IP.
  Fisika dihitung di tiap HP; tidak ada akun/anti-curang.
- Tesla Roadster Terbang (12.000 koin): tombol TERBANG (keyboard F), NAIK/TURUN (E/Q).
- Android: aktifkan izin INTERNET saat export. Turunkan RENDER_SCALE di car.gd bila HP lambat.
- Model asli: taruh models/mobil.glb (otomatis dipakai).

=== PERBAIKAN (21 Okt) ===
- Lag: RENDER_SCALE 1.7->1.0, MSAA 4x->2x, bayangan 4096/4 split -> 2048/2 split, filter bayangan lebih ringan.
  Bila masih berat di HP lemah: RENDER_SCALE=0.85 di main.gd.
- Suara mesin: tabel gelombang + filter rpm, desis intake, limiter, letupan knalpot, siulan nitro.
- Jaringan: klien yang belum tersambung tidak lagi memanggil RPC (error berulang).

=== LOBI BARU & MOBIL BARU (22 Okt) ===
- Lobi kota malam neon; tombol MOBIL membuka garasi (grafik statistik, panah ganti mobil, beli/pakai).
- Mobil baru: Hyper Viola GT (9.000 koin, sayap GT, velg menyala) dan Aero Verde Chrome (15.000 koin, cat krom kameleon).

=== FISIKA: TIDAK MELAYANG (22 Okt) ===
- Sudut setir dibatasi percepatan samping (LAT_MAKS di car.gd), pusat massa diturunkan, anti-guling, gravitasi 1.6x (GRAVITASI).
- Lompatan di sirkuit diperkecil (tinggi 1.9 m -> 0.6 m). Bila mau lebih seru, naikkan `tinggi` di main.gd (_lompatan).

=== GALERI, INTERIOR, MOBIL BARU (23 Okt) ===
- Garasi: tombol LUAR / DEPAN / BELAKANG / DALAM (kamera kokpit), strip thumbnail 3D untuk 9 mobil.
- Kaca bodi kini tembus pandang: interior (kursi, dasbor, setir, layar, konsol) terlihat dari luar dan dalam.
- Mobil baru: Stallion GT Biru (7.000), Heritage GT Putih (11.000), Crimson Roadster (13.000).
