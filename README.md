# mPOS Distributor

Aplikasi POS distributor untuk **Android, iOS, dan Web** berdasarkan PRD "Aplikasi POS Distributor".
Flutter + Riverpod (state management) + arsitektur MVVM per fitur + Firebase (Auth & Cloud Firestore).

## Arsitektur

```
lib/
  core/                 # dipakai semua fitur
    error/              # AppException (pesan aman untuk pengguna)
    firebase/           # provider Firebase, nama koleksi, parsing, audit & mutasi stok
    router/             # go_router + guard per role, AppShell (menu)
    viewmodel/          # ActionViewModel: basis ViewModel untuk aksi (simpan/proses)
    widgets/ utils/ theme/
  features/<fitur>/
    domain/             # Entity, interface Repository, service murni (tanpa Flutter/Firebase)
    data/               # Model (map <-> entity) + implementasi Repository Firestore
    presentation/
      viewmodels/       # Notifier Riverpod = ViewModel
      views/            # Widget = View, hanya membaca state & memanggil ViewModel
    <fitur>_providers.dart  # dependency injection (Provider repository & stream)
```

Alur data: **View → ViewModel (Notifier) → Repository (interface di domain) → Firestore**.
Aturan bisnis penting ada di `domain/services` dan dites tanpa Firebase:

| Service | Isi |
| --- | --- |
| `sales/domain/services/cart_rules.dart` | Gabung item sama, cek stok kumulatif, harga grosir otomatis, harga manual, batasi qty Customer |
| `pricing/domain/services/pricing_service.dart` | Harga khusus/promo per item, akun, item+akun; pilih potongan terbesar; promo katalog |
| `sales/domain/services/sale_calculator.dart` | Subtotal − diskon item − diskon nota + pajak; Tunai/Transfer/DP/Tempo |
| `stock/domain/services/stock_calculator.dart` | HPP rata-rata tertimbang, selisih koreksi stok masuk |
| `core/router/app_router.dart` → `resolveRedirect` | Hak akses halaman per role |

## Fitur per role

| Role | Halaman |
| --- | --- |
| Owner | Dashboard, Kasir (POS), Pesanan online, Riwayat nota + pelunasan DP, Produk (+ stok minimum, grosir, hitung stok, stock opname), Stok masuk, Approval koreksi SPV, Harga khusus & promo, Pengeluaran, Laporan laba rugi, Pengguna, Pengaturan toko & nota |
| SPV | Stok masuk, ajukan perubahan (perlu ACC Owner), status pengajuan |
| Customer | Katalog (harga normal, promo publik), keranjang (qty dibatasi stok), pesanan saya, nota saya |

Diskon tersembunyi: Customer tidak pernah membaca koleksi `discounts` kecuali promo publik.
Diskon dihitung saat Owner memproses pesanan, lalu muncul di invoice sebagai "Diskon pelanggan".

## Setup Firebase (sekali)

1. Pasang CLI lalu hubungkan project `mpos-da4b9`:

   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --project=mpos-da4b9 --platforms=android,ios,web
   ```

   Perintah terakhir menimpa `lib/firebase_options.dart` (sekarang placeholder). Selama masih placeholder,
   aplikasi menampilkan layar petunjuk setup.

2. Di Firebase Console: aktifkan **Authentication → Email/Password** dan buat **Cloud Firestore**.
3. Deploy security rules:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

4. Owner pertama: daftar lewat tombol "Daftar sebagai pelanggan", lalu di Firestore Console ubah
   `users/{uid}.role` menjadi `owner`. Setelah itu Owner bisa mengubah role akun lain (mis. SPV) dari menu Pengguna.

## Menjalankan

```bash
flutter pub get
flutter run -d chrome      # web
flutter run                # Android / iOS
flutter test               # unit test logika bisnis & guard role
flutter analyze
```

## Belum dikerjakan (sesuai PRD, tahap berikutnya)

- Cetak ke printer thermal 58/80 mm, PDF invoice/faktur, dan bagikan WhatsApp (data jenis nota sudah ada di Pengaturan).
- Revisi invoice (INV-xxx-R1) oleh Owner.
- Impor data awal dari Aplikasi Kasir Excel.
- Batal otomatis pesanan "Menunggu" yang terlalu lama mengunci stok.
- Notifikasi (stok minimum, pesanan baru) via FCM/WhatsApp.
- Pindahkan checkout & perubahan stok ke **Cloud Functions** untuk produksi: saat ini rules mengizinkan
  pengguna aktif mengubah field `stock` (dibutuhkan transaksi dari klien).
- Mode offline kasir.
