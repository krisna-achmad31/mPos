import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/products/domain/entities/product_categories.dart';
import 'package:mpos/features/reports/domain/demo_catalog.dart';

void main() {
  test('semua produk contoh memakai kategori bawaan, dan setiap kategori bawaan terisi', () {
    final used = DemoCatalog.products.map((p) => p.category).toSet();
    expect(used.difference(ProductCategories.defaults.toSet()), isEmpty);
    expect(ProductCategories.defaults.toSet().difference(used), isEmpty);
  });

  test('harga kemasan contoh lebih murah dari harga satuan x isi', () {
    for (final p in DemoCatalog.products) {
      for (final pack in p.packs) {
        expect(pack.price, lessThanOrEqualTo(pack.contents * p.sellPrice), reason: '${p.name} ${pack.name}');
      }
    }
  });
}
