# Changelog

Catatan perubahan terbaru ditulis paling atas. Setiap entri mencantumkan tanggal, developer, dan daftar fitur/perbaikan. Riwayat sebelum 1 November 2026 diringkas dari commit Git; nama developer mengikuti author commit.

## 2026-11-02

Developer: Achmad Yukrisna (dibantu Claude)

- Perbaikan: daftar barang di keranjang Kasir tidak tampil di layar lebar (web desktop); `SectionCard` kini punya opsi `expand`.
- Hapus dokumen stok masuk khusus owner dari tab Riwayat: stok ditarik kembali, HPP rata-rata dihitung ulang, ditolak bila stok akan minus atau dokumen masih menunggu ACC koreksi.
- Menu **Backup data** (owner): backup harian otomatis seluruh data distributor mulai 00.00 WIB saat aplikasi owner terbuka, disimpan 4 hari terakhir di perangkat (folder aplikasi / IndexedDB browser) dan Google Drive owner.
- Load backup: ganti semua data atau sebagian (per kelompok data), dengan peringatan dan backup otomatis "sebelum load" agar bisa dibatalkan; backup juga bisa diunduh dan di-load dari file.
- Rules produksi: owner boleh menghapus stok masuk dan menulis ulang semua data distributornya (dibutuhkan saat load backup).

## 2026-11-01

Developer: Achmad Yukrisna (dibantu Codex)

- Pilihan tanggal transaksi kasir: hari ini atau tanggal sebelumnya, tersedia sebelum pencarian produk.
- Tanggal transaksi dipakai untuk nomor nota, tanggal nota, pembayaran awal, HPP, dan laporan; tanggal masa depan ditolak.
- Hapus transaksi khusus owner dari kartu riwayat atau detail nota, dengan dialog konfirmasi.
- Penghapusan nota dan pembayaran dilakukan bersama pengembalian stok serta pencatatan audit; stok nota yang sudah dibatalkan tidak dikembalikan dua kali.
- Penghapusan pesanan yang sudah diterima ke stok POS kopi ditolak untuk menjaga konsistensi stok pelanggan.
- Rules produksi mengizinkan owner menghapus pembayaran; mode pilot tetap memerlukan login dan rules produksi untuk pembatasan akses di server.
- Tambahan pengujian hak owner, konfirmasi penghapusan, serta penerusan dan reset tanggal saat checkout.
- Mulai dokumentasi riwayat perubahan dalam changelog ini.

## 2026-10-31

Developer: Achmad Yukrisna — commit `0d7ce34`

- Harga khusus pelanggan, ekspor produk, dan laporan persediaan.

## 2026-10-18

Developer: achmad_yukrisna — commit `eefaa86`

- HPP rata-rata, saran harga jual, dan pratinjau pada stok masuk.
- Pencegahan barcode produk duplikat.

## 2026-10-16

Developer: Achmad Yukrisna — commit `b5b49a8`

- Penerapan desain `design_ui.pen` ke seluruh halaman.
- Dukungan mode gelap.

## 2026-10-14

Developer: achmad_yukrisna — commit `db6382a`, `0b8b11f`, `5e5acc0`, `c5fbcfe`

- Bundling produk dan harga bundling per isi.
- Tabel produk, filter stok, total stok, dan nilai barang.
- Keterangan isi kemasan dan satuan jual karton/bal/sak.
- Kolom keterangan serta indikator loading pada halaman produk.

## 2026-10-12

Developer: achmad_yukrisna — commit `bf57e9a`, `98985ae`, `97bce3b`, `ef07bdc`, `1892875`, `06dedc8`, `1808775`, `cdbf260`

- POS kopi pelanggan distributor: resep, stok terintegrasi, struk thermal, dan kode premium.
- Ekspor penjualan ke Excel dengan pilihan rentang tanggal, bulan, atau tahun.
- Pengeluaran diperhitungkan dalam laba bersih laporan.
- Pembayaran tempo dengan jatuh tempo serta pemisahan transfer dan QRIS.
- Foto produk berbasis base64 dengan gambar pengganti.
- Header nota mengikuti nama toko dari pengaturan.
- Pengecualian helper BLE Windows dari hosting web agar sesuai batasan paket Spark.
