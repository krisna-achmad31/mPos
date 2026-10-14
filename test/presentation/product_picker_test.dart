import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/widgets/product_picker.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/product_providers.dart';

void main() {
  const kopi = Product(id: 'kopi', name: 'Kopi Arabika', sellPrice: 50000, stock: 10);
  const paket = Product(
    id: 'paket',
    name: 'Paket Arabika',
    sellPrice: 90000,
    bundleItems: [BundleItem(productId: 'kopi', name: 'Kopi Arabika', qty: 2)],
  );

  Future<void> pump(WidgetTester tester, {required bool includeBundles}) => tester.pumpWidget(
        ProviderScope(
          overrides: [activeProductsProvider.overrideWith((ref) => Stream.value(const [kopi, paket]))],
          child: MaterialApp(
            home: Scaffold(body: ProductPicker(includeBundles: includeBundles, onSelected: (_) {})),
          ),
        ),
      );

  testWidgets('pencarian menampilkan produk & bundling', (tester) async {
    await pump(tester, includeBundles: true);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'arabika');
    await tester.pumpAndSettle();
    expect(find.text('Kopi Arabika'), findsOneWidget);
    expect(find.text('Paket Arabika (bundling)'), findsOneWidget);
  });

  testWidgets('stok masuk / isi bundling: bundling disembunyikan', (tester) async {
    await pump(tester, includeBundles: false);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'arabika');
    await tester.pumpAndSettle();
    expect(find.text('Kopi Arabika'), findsOneWidget);
    expect(find.textContaining('Paket'), findsNothing);
  });
}
