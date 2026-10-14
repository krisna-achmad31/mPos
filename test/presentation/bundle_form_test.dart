import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/presentation/views/bundle_form_view.dart';
import 'package:mpos/features/products/product_providers.dart';

void main() {
  testWidgets('harga paket mengikuti harga per isi yang diedit', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const kopi = Product(id: 'kopi', name: 'Kopi', sellPrice: 50000, stock: 10);
    const susu = Product(id: 'susu', name: 'Susu', sellPrice: 20000, stock: 10);
    const bundle = Product(
      id: 'b1',
      name: 'Paket',
      sellPrice: 100000,
      bundleItems: [
        BundleItem(productId: 'kopi', name: 'Kopi', qty: 2, price: 50000, bundlePrice: 40000),
        BundleItem(productId: 'susu', name: 'Susu', qty: 1, price: 20000),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value(const [kopi, susu, bundle])),
        activeProductsProvider.overrideWith((ref) => Stream.value(const [kopi, susu, bundle])),
        productCostsProvider.overrideWith((ref) => Stream.value(const {})),
      ],
      child: const MaterialApp(home: BundleForm(bundle: bundle)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2 × = Rp80.000'), findsOneWidget);
    expect(find.text('Rp100.000'), findsWidgets); // harga bundling (+ laba, modal 0)
    expect(find.text('Hemat Rp10.000 / pcs'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, '40000'), '45000');
    await tester.pump();

    expect(find.text('2 × = Rp90.000'), findsOneWidget);
    expect(find.text('Rp110.000'), findsWidgets);
    expect(find.text('Hemat Rp5.000 / pcs'), findsOneWidget);
  });
}
