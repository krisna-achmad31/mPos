import '../entities/product.dart';

/// Saran harga jual dari HPP rata-rata + margin Owner. Hanya saran: harga jual tidak pernah berubah sendiri.
abstract final class PriceSuggestion {
  static const defaultMarginPercent = 20.0;
  static const defaultRounding = 500;

  /// Pilihan pembulatan ke atas di Pengaturan.
  static const roundingOptions = [100, 500, 1000];

  /// HPP × (1 + margin%), dibulatkan ke atas ke kelipatan [roundTo]. 0 bila modal belum diketahui.
  static int suggest(int unitCost, double marginPercent, {int roundTo = defaultRounding}) {
    if (unitCost <= 0) return 0;
    final raw = (unitCost * (100 + marginPercent) / 100).ceil();
    if (roundTo <= 1) return raw;
    return ((raw + roundTo - 1) ~/ roundTo) * roundTo;
  }

  /// Margin harga jual terhadap modal, dalam persen (dibulatkan). null bila modal belum diketahui.
  static int? marginOf(int sellPrice, int unitCost) {
    if (unitCost <= 0) return null;
    return ((sellPrice - unitCost) / unitCost * 100).round();
  }
}

/// Barcode harus unik: produk yang sama dari supplier mana pun ditambah lewat Stok Masuk,
/// agar stok dan HPP rata-ratanya tetap di satu produk.
abstract final class BarcodeRules {
  /// Produk lain yang sudah memakai [barcode], atau null.
  static Product? owner(Iterable<Product> products, String barcode, {String excludeId = ''}) {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    for (final p in products) {
      if (p.id != excludeId && p.barcode.trim() == code) return p;
    }
    return null;
  }
}
