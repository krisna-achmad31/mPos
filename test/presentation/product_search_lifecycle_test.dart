import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/presentation/viewmodels/product_view_models.dart';
import 'package:mpos/features/products/presentation/views/product_list_view.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';
import 'package:mpos/features/settings/settings_providers.dart';

void main() {
  testWidgets('kembali ke daftar menghapus pencarian lama tanpa logout', (tester) async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value(const [
            Product(id: 'fanta', name: 'Fanta', sellPrice: 5000),
            Product(id: 'sprite', name: 'Sprite', sellPrice: 5000),
          ]),
        ),
        productCostsProvider.overrideWith((ref) => Stream.value(const {})),
        categoriesProvider.overrideWith((ref) => Stream.value(const [])),
        storeSettingsProvider.overrideWith((ref) => Stream.value(const StoreSettings())),
      ],
    );
    addTearDown(container.dispose);
    Future<void> show(Widget child) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const ProductListView());
    await tester.enterText(find.byType(TextField), 'fanta');
    await tester.pumpAndSettle();
    expect(container.read(filteredProductsProvider).value!.map((p) => p.id), ['fanta']);
    await show(const Scaffold(body: Text('Detail produk')));
    await show(const ProductListView());
    expect(container.read(productSearchProvider), '');
    expect(container.read(filteredProductsProvider).value, hasLength(2));
  });
}
