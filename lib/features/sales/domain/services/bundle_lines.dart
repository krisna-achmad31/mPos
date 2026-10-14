import '../entities/cart_line.dart';

/// Baris bundling di nota/pesanan dijabarkan ke produk isinya untuk stok, HPP, dan stok POS kopi.
abstract final class BundleLines {
  /// Qty yang memotong stok per produk. Bundling dijabarkan ke isinya;
  /// produk tanpa stok tetap ikut (repository yang melewatinya setelah membaca dokumennya).
  static Map<String, int> stockQtyByProduct(List<CartLine> lines) {
    final result = <String, int>{};
    void add(String id, int qty) => result[id] = (result[id] ?? 0) + qty;
    for (final l in lines) {
      if (l.isBundle) {
        for (final c in l.components) {
          if (c.trackStock) add(c.productId, c.qty * l.qty);
        }
      } else if (l.trackStock) {
        add(l.productId, l.qty);
      }
    }
    return result;
  }

  /// Id produk yang HPP-nya perlu dibaca: produk biasa + isi bundling.
  static Set<String> costProductIds(List<CartLine> lines) => {
        for (final l in lines)
          if (l.isBundle) ...l.components.map((c) => c.productId) else l.productId,
      };

  /// Modal satu unit baris: bundling = jumlah HPP isinya × qty per paket.
  static int unitCost(CartLine l, Map<String, int> hpp) => l.isBundle
      ? l.components.fold(0, (s, c) => s + (hpp[c.productId] ?? 0) * c.qty)
      : hpp[l.productId] ?? 0;

  /// Bundling → baris per isi. Nilai bersih paket dibagi ke isinya sebanding harga normal,
  /// agar HPP stok POS kopi pelanggan mencerminkan harga paket yang dibayar.
  static List<CartLine> expand(List<CartLine> lines) => [
        for (final l in lines)
          if (!l.isBundle) l else ..._split(l),
      ];

  static List<CartLine> _split(CartLine l) {
    final weights = [for (final c in l.components) (c.price > 0 ? c.price : 1) * c.qty];
    final totalWeight = weights.fold(0, (s, w) => s + w);
    var allocated = 0;
    return [
      for (var i = 0; i < l.components.length; i++)
        () {
          final c = l.components[i];
          final qty = c.qty * l.qty;
          final last = i == l.components.length - 1;
          final value = last ? l.net - allocated : (l.net * weights[i] / totalWeight).round();
          allocated += value;
          return CartLine(
            productId: c.productId,
            name: c.name,
            unit: c.unit,
            qty: qty,
            unitPrice: qty == 0 ? 0 : (value / qty).round(),
            priceType: l.priceType,
            trackStock: c.trackStock,
          );
        }(),
    ];
  }
}
