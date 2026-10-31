import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/utils/money.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/reports/presentation/widgets/inventory_value_tile.dart';

void main() {
  Future<void> show(WidgetTester tester, Stream<List<Product>> products, Stream<Map<String, ProductCost>> costs) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith((ref) => products),
          productCostsProvider.overrideWith((ref) => costs),
        ],
        child: const MaterialApp(home: Scaffold(body: InventoryValueTile())),
      ),
    );
    await tester.pump();
  }

  testWidgets('nilai stok mengikuti HPP dan tidak menjumlahkan bundle', (tester) async {
    await show(
      tester,
      Stream.value(const [
        Product(id: 'p', name: 'Produk', sellPrice: 10000, stock: 10),
        Product(
          id: 'b',
          name: 'Bundle',
          sellPrice: 18000,
          stock: 5,
          bundleItems: [BundleItem(productId: 'p', name: 'Produk', qty: 2)],
        ),
      ]),
      Stream.value(const {'p': ProductCost(productId: 'p', buyPrice: 5000, hpp: 6000)}),
    );
    expect(find.text(formatRupiah(60000)), findsOneWidget);
    expect(find.text('Nilai stok saat ini'), findsOneWidget);
  });

  testWidgets('menunggu modal sebelum menampilkan total', (tester) async {
    final costs = StreamController<Map<String, ProductCost>>();
    addTearDown(costs.close);
    await show(
      tester,
      Stream.value(const [Product(id: 'p', name: 'Produk', sellPrice: 10000, stock: 10)]),
      costs.stream,
    );
    expect(find.text('Memuat...'), findsOneWidget);
    expect(find.text(formatRupiah(0)), findsNothing);
    costs.add(const {'p': ProductCost(productId: 'p', buyPrice: 5000)});
    await tester.pump();
    await tester.pump();
    expect(find.text(formatRupiah(50000)), findsOneWidget);
  });

  testWidgets('modal hilang tidak ditampilkan sebagai total lengkap', (tester) async {
    await show(
      tester,
      Stream.value(const [Product(id: 'p', name: 'Produk', sellPrice: 10000, stock: 10)]),
      Stream.value(const {}),
    );
    expect(find.text('Belum lengkap'), findsOneWidget);
    expect(find.text(formatRupiah(0)), findsNothing);
  });
}
