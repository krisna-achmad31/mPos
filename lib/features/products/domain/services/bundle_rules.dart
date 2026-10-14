import '../../../../core/error/app_exception.dart';
import '../entities/product.dart';

/// Aturan bundling (paket beberapa produk dengan harga sendiri).
abstract final class BundleRules {
  /// Stok bundling = paket utuh yang bisa dibentuk dari stok isinya.
  /// Isi yang hilang / nonaktif membuat paket tidak bisa dijual (stok 0).
  static List<Product> resolveStock(List<Product> products) {
    if (!products.any((p) => p.isBundle)) return products;
    final byId = {for (final p in products) p.id: p};
    return [for (final p in products) p.isBundle ? _resolve(p, byId) : p];
  }

  static Product _resolve(Product bundle, Map<String, Product> byId) {
    var tracked = false;
    int? available;
    for (final item in bundle.bundleItems) {
      final component = byId[item.productId];
      if (component == null || !component.active || component.isBundle || item.qty <= 0) {
        return bundle.copyWith(trackStock: true, stock: 0);
      }
      if (!component.trackStock) continue;
      tracked = true;
      final packs = component.stock <= 0 ? 0 : component.stock ~/ item.qty;
      available = available == null || packs < available ? packs : available;
    }
    return bundle.copyWith(trackStock: tracked, stock: available ?? 0);
  }

  /// Total harga normal isi paket (harga satuan × qty).
  static int normalPrice(List<BundleItem> items) => items.fold(0, (s, i) => s + i.normalTotal);

  /// Harga paket = jumlah harga per isi × qty yang diinput Owner.
  static int bundlePrice(List<BundleItem> items) => items.fold(0, (s, i) => s + i.bundleTotal);

  /// Modal paket dari modal per isi.
  static int cost(List<BundleItem> items, int Function(String productId) unitCost) =>
      items.fold(0, (s, i) => s + unitCost(i.productId) * i.qty);

  static void validate(Product bundle) {
    final items = bundle.bundleItems;
    if (items.isEmpty) throw const AppException('Pilih minimal satu produk untuk isi bundling.');
    if (items.any((i) => i.qty <= 0)) throw const AppException('Qty tiap isi bundling harus lebih dari 0.');
    for (final i in items) {
      if (i.bundlePrice <= 0) throw AppException('Harga ${i.name} di bundling harus lebih dari 0.');
    }
    if (bundle.sellPrice != bundlePrice(items)) {
      throw const AppException('Harga bundling harus sama dengan jumlah harga isinya.');
    }
    if (items.fold(0, (s, i) => s + i.qty) < 2) {
      throw const AppException('Bundling minimal berisi 2 barang (mis. 2 produk, atau 1 produk qty 2).');
    }
    final ids = items.map((i) => i.productId).toList();
    if (ids.toSet().length != ids.length) throw const AppException('Produk yang sama hanya boleh sekali di bundling.');
    if (ids.contains(bundle.id)) throw const AppException('Bundling tidak boleh berisi dirinya sendiri.');
  }

  /// Mis. "2× Kopi Arabica, 1× Susu UHT".
  static String contentsLabel(List<BundleItem> items) =>
      items.map((i) => '${i.qty}× ${i.name}').join(', ');
}
