import '../../../core/firebase/collections.dart';

/// Bagian data yang bisa di-load terpisah. Koleksi yang saling bergantung
/// (mis. nota + nomor urut nota) selalu berada di grup yang sama.
enum BackupGroup {
  products('Produk, HPP & harga', [
    Collections.products,
    Collections.productCosts,
    Collections.priceHistory,
    Collections.discounts,
  ]),
  stock('Stok masuk, mutasi & opname', [
    Collections.stockReceipts,
    Collections.stockMovements,
    Collections.stockOpnames,
    Collections.changeRequests,
  ]),
  sales('Pesanan, nota & pembayaran', [
    Collections.orders,
    Collections.invoices,
    Collections.invoiceCosts,
    Collections.payments,
    Collections.counters,
  ]),
  expenses('Pengeluaran', [Collections.expenses]),
  settings('Pengaturan & profil distributor', [Collections.settings]),
  premium('Kode premium POS Kopi', [Collections.premiumCodes]),
  users('Akun pengguna & role', []),
  logs('Log audit & data demo', [Collections.auditLogs, Collections.demoDays]);

  const BackupGroup(this.label, this.collections);

  final String label;

  /// Subkoleksi di bawah dokumen distributor.
  final List<String> collections;

  /// Semua subkoleksi distributor yang ikut di-backup.
  static List<String> get allCollections => [for (final g in values) ...g.collections];
}
