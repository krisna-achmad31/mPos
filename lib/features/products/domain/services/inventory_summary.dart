import '../entities/product.dart';

/// Indikator stok di daftar produk: hijau aman, kuning menipis (≤ stok minimum), merah habis.
enum StockLevel {
  safe('Aman'),
  low('Menipis'),
  out('Habis'),

  /// Jasa / barang tanpa stok.
  untracked('Tanpa stok');

  const StockLevel(this.label);

  final String label;

  static StockLevel of(Product p) {
    if (!p.trackStock) return untracked;
    if (p.stock <= 0) return out;
    if (p.stock <= p.minStock) return low;
    return safe;
  }
}

/// Total stok & nilai barang untuk Owner.
/// Bundling tidak dihitung: stoknya hanya turunan dari stok isinya (sudah terhitung).
class InventorySummary {
  const InventorySummary({required this.totalStock, required this.totalValue, required this.productCount});

  final int totalStock;
  final int totalValue;
  final int productCount;

  /// Modal per satuan: HPP rata-rata, atau harga beli bila HPP belum ada.
  static int unitCost(ProductCost? cost) {
    if (cost == null) return 0;
    return cost.hpp > 0 ? cost.hpp : cost.buyPrice;
  }

  /// Nilai barang satu produk = stok × modal. Stok minus dianggap 0.
  static int valueOf(Product p, ProductCost? cost) {
    if (!p.trackStock || p.isBundle || p.stock <= 0) return 0;
    return p.stock * unitCost(cost);
  }

  static InventorySummary of(Iterable<Product> products, Map<String, ProductCost> costs) {
    var stock = 0;
    var value = 0;
    var count = 0;
    for (final p in products) {
      if (p.isBundle || !p.trackStock) continue;
      count++;
      if (p.stock > 0) stock += p.stock;
      value += valueOf(p, costs[p.id]);
    }
    return InventorySummary(totalStock: stock, totalValue: value, productCount: count);
  }
}
