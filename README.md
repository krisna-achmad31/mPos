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

## Multi-distributor

Setiap distributor punya ruang data sendiri. Akun (`users/{uid}`) menyimpan `distributorId` + `role`,
dan semua repository membaca/menulis lewat `TenantStore` (`lib/core/firebase/tenant_store.dart`):

```
distributors/{distributorId}            # nama, ownerUid
  products, product_costs, stock_receipts, stock_movements, stock_opnames, change_requests,
  discounts, orders, invoices, invoice_costs, payments, expenses, counters, settings,
  demo_days, audit_logs
users/{uid}                              # name, role, distributorId, active
```

- Daftar sebagai **distributor baru** → membuat distributor + menjadi Owner-nya.
- Daftar sebagai **pelanggan** → memilih distributor tempat belanja.
- `firestore.rules` membatasi akses ke data distributor milik akun sendiri.
- Mode pilot (`AppConfig.demoMode = true`): pilih distributor (atau buat baru) lalu pilih role tanpa login;
  tersedia 2 akun Customer uji per distributor. Data pilot lama dipindahkan ke distributor `pilot`.

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

## Design system & tata letak responsif

Seluruh tampilan mengikuti file desain `design_ui.pen` (pen.dev) dengan satu sumber token:

| Berkas | Isi |
| --- | --- |
| `lib/core/theme/app_tokens.dart` | `AppPalette` (primary `#245FE5`, ink `#17243B`, muted `#69758A`, canvas `#F5F7FB`, line `#E5EAF2`, success `#147D61`, warning `#996310`, danger `#BC3F50` + tint), `AppRadius`, `AppSpacing`, `Breakpoints`, `DeviceClass`, `context.tokens`, `context.deviceClass` |
| `lib/core/theme/app_theme.dart` | ColorScheme eksplisit, text theme, dan tema komponen (Card, Input, Button, Nav, Dialog, Snackbar) |
| `lib/core/widgets/app_layout.dart` | `PageScaffold` (app bar jejak lokasi + page heading), `SectionCard`, `KpiTile`/`KpiRow`, `InfoRow`, `AppDataTable` |
| `lib/core/widgets/status_badge.dart` | `StatusBadge` + `BadgeTone` (neutral/info/success/warning/danger) |
| `lib/core/widgets/app_timeline.dart` | `AppTimeline` untuk langkah pesanan/resep |
| `lib/features/sales/presentation/widgets/sales_badges.dart` | Lencana status pesanan, pembayaran, dan tempo |

Titik henti tata letak (`Breakpoints`):

| Lebar | Navigasi | Konten |
| --- | --- | --- |
| `< 600` (HP) | bottom navigation (4 tab + `Akun`) | daftar kartu, bukan tabel |
| `600–999` (tablet) | rel ikon 76 px | tabel & grid rapat |
| `>= 1000` (web) | sidebar 224 px + bagian menu | konten maks 1240 px di tengah |

Catatan font: desain memakai **Inter**. `AppTheme` sudah menulis `fontFamily: 'Inter'` dengan fallback
(`Roboto`, `Segoe UI`, …), tetapi berkas fontnya belum dibundel. Agar sama persis dengan desain, tambahkan
aset Inter lalu daftarkan di `pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Inter-Bold.ttf
          weight: 700
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
