import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/cafe/data/cafe_account_repository.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/domain/services/bundle_rules.dart';
import 'package:mpos/features/products/domain/services/inventory_summary.dart';
import 'package:mpos/features/sales/data/models/sales_models.dart';
import 'package:mpos/features/sales/domain/services/bundle_lines.dart';
import 'package:mpos/features/sales/domain/services/cart_rules.dart';

import '../helpers.dart';

void main() {
  const kopi = BundleItem(productId: 'kopi', name: 'Kopi', qty: 2, price: 50000);
  const susu = BundleItem(productId: 'susu', name: 'Susu', qty: 1, price: 20000);
  const bundle = Product(id: 'b1', name: 'Paket', unit: 'paket', sellPrice: 100000, trackStock: false, bundleItems: [kopi, susu]);

  group('BundleRules', () {
    test('stok paket = paket utuh dari stok isi terkecil', () {
      final resolved = BundleRules.resolveStock([
        product(id: 'kopi', stock: 9),
        product(id: 'susu', stock: 10),
        bundle,
      ]);
      final b = resolved.last;
      expect(b.trackStock, isTrue);
      expect(b.stock, 4); // 9 kopi / 2
      expect(b.needsReorder, isFalse, reason: 'bundling tidak masuk daftar restock');
    });

    test('isi hilang atau nonaktif membuat paket habis', () {
      expect(BundleRules.resolveStock([product(id: 'kopi', stock: 9), bundle]).last.stock, 0);
      final inactive = product(id: 'susu', stock: 10).copyWith(active: false);
      expect(BundleRules.resolveStock([product(id: 'kopi', stock: 9), inactive, bundle]).last.isOutOfStock, isTrue);
    });

    test('isi tanpa stok (jasa) tidak membatasi paket', () {
      final resolved = BundleRules.resolveStock([
        product(id: 'kopi', stock: 0, trackStock: false),
        product(id: 'susu', stock: 0, trackStock: false),
        bundle,
      ]);
      expect(resolved.last.trackStock, isFalse);
    });

    test('harga normal & validasi', () {
      expect(BundleRules.normalPrice(bundle.bundleItems), 120000);
      expect(() => BundleRules.validate(bundle.copyWith(bundleItems: [])), throwsA(isA<AppException>()));
      expect(
        () => BundleRules.validate(bundle.copyWith(bundleItems: [susu])),
        throwsA(isA<AppException>()),
        reason: 'minimal 2 barang',
      );
      expect(() => BundleRules.validate(bundle.copyWith(bundleItems: [kopi, kopi])), throwsA(isA<AppException>()));
      BundleRules.validate(bundle);
    });
  });

  group('BundleLines', () {
    final products = BundleRules.resolveStock([product(id: 'kopi', stock: 9), product(id: 'susu', stock: 10), bundle]);
    final b = products.last;

    test('qty stok dijabarkan ke isi, digabung dengan produk biasa', () {
      var lines = CartRules.addItem(const [], b, qty: 3);
      lines = CartRules.addItem(lines, products.first, qty: 2);
      expect(lines.first.isBundle, isTrue);
      expect(BundleLines.stockQtyByProduct(lines), {'kopi': 8, 'susu': 3});
      expect(BundleLines.costProductIds(lines), {'kopi', 'susu'});
    });

    test('HPP paket = jumlah HPP isi', () {
      final line = CartRules.addItem(const [], b).first;
      expect(BundleLines.unitCost(line, {'kopi': 30000, 'susu': 12000}), 72000);
    });

    test('baris paket bertahan bolak-balik Firestore', () {
      final line = CartRules.addItem(const [], b, qty: 2).first;
      final back = SalesModels.lineFromMap(SalesModels.lineToMap(line));
      expect(back.components, line.components);
      expect(back.gross, 200000);
    });

    test('stok POS kopi menerima isi paket, nilai dibagi sebanding harga normal', () {
      final line = CartRules.addItem(const [], b).first;
      final received = CafeStockReceipt.receivableLines([line]);
      expect(received.map((l) => (l.productId, l.qty)), [('kopi', 2), ('susu', 1)]);
      // 100.000 dibagi 100.000 : 20.000
      expect(received.fold(0, (s, l) => s + l.net), closeTo(100000, 2));
      expect(received.first.net, closeTo(83333, 1));
    });
  });

  group('InventorySummary', () {
    test('total stok & nilai barang tanpa bundling dan tanpa stok minus', () {
      final products = [
        product(id: 'kopi', stock: 10),
        product(id: 'susu', stock: -2),
        product(id: 'jasa', stock: 0, trackStock: false),
        bundle.copyWith(trackStock: true, stock: 5),
      ];
      final costs = {
        'kopi': const ProductCost(productId: 'kopi', buyPrice: 9000, hpp: 10000),
        'susu': const ProductCost(productId: 'susu', buyPrice: 5000),
      };
      final s = InventorySummary.of(products, costs);
      expect(s.totalStock, 10);
      expect(s.totalValue, 100000);
      expect(s.productCount, 2);
    });

    test('indikator stok', () {
      expect(StockLevel.of(product(stock: 0)), StockLevel.out);
      expect(StockLevel.of(product(stock: 3, minStock: 5)), StockLevel.low);
      expect(StockLevel.of(product(stock: 6, minStock: 5)), StockLevel.safe);
      expect(StockLevel.of(product(trackStock: false)), StockLevel.untracked);
    });
  });
}
