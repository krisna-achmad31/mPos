import '../../../../core/error/app_exception.dart';
import '../entities/stock_receipt.dart';

/// Aturan hitung stok yang tidak bergantung pada Firebase, agar mudah dites.
abstract final class StockCalculator {
  /// HPP rata-rata tertimbang setelah barang masuk.
  static int averageCost({
    required int currentStock,
    required int currentHpp,
    required int incomingQty,
    required int incomingPrice,
  }) {
    final base = currentStock < 0 ? 0 : currentStock;
    final totalQty = base + incomingQty;
    if (totalQty <= 0) return incomingPrice;
    return ((base * currentHpp + incomingQty * incomingPrice) / totalQty).round();
  }

  /// HPP [productId] setelah semua [items] dokumen ini masuk, dihitung berurutan seperti saat disimpan.
  static int projectedHpp({
    required String productId,
    required int currentStock,
    required int currentHpp,
    required Iterable<StockReceiptItem> items,
  }) {
    var stock = currentStock;
    var hpp = currentHpp;
    for (final item in items.where((i) => i.productId == productId)) {
      hpp = averageCost(currentStock: stock, currentHpp: hpp, incomingQty: item.qty, incomingPrice: item.buyPrice);
      stock += item.qty;
    }
    return hpp;
  }

  /// Selisih qty per produk antara isi dokumen lama dan baru (baru − lama).
  static Map<String, int> deltas(List<StockReceiptItem> oldItems, List<StockReceiptItem> newItems) {
    final result = <String, int>{};
    for (final item in oldItems) {
      result[item.productId] = (result[item.productId] ?? 0) - item.qty;
    }
    for (final item in newItems) {
      result[item.productId] = (result[item.productId] ?? 0) + item.qty;
    }
    result.removeWhere((_, delta) => delta == 0);
    return result;
  }

  static void validateItems(List<StockReceiptItem> items) {
    if (items.isEmpty) throw const AppException('Tambahkan minimal satu barang.');
    for (final item in items) {
      if (item.qty <= 0) throw AppException('Qty ${item.productName} harus lebih dari 0.');
      if (item.buyPrice < 0) throw AppException('Harga beli ${item.productName} tidak valid.');
    }
  }
}
