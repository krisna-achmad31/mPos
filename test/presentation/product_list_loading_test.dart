import 'dart:async';

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
  const kopi = Product(id: 'kopi', name: 'Kopi', sellPrice: 50000, stock: 10);

  Future<StreamController<Map<String, ProductCost>>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final costs = StreamController<Map<String, ProductCost>>();
    addTearDown(costs.close);
    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value(const [kopi])),
      productCostsProvider.overrideWith((ref) => costs.stream),
      categoriesProvider.overrideWith((ref) => Stream.value(const [])),
      storeSettingsProvider.overrideWith((ref) => Stream.value(const StoreSettings())),
    ]);
    addTearDown(container.dispose);
    container.read(productViewModeProvider.notifier).set(ProductViewMode.table);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProductListView()),
    ));
    await tester.pump();
    return costs;
  }

  testWidgets('total & kolom modal menampilkan loading sampai harga modal terbaca', (tester) async {
    final costs = await pump(tester);
    expect(find.text('Memuat…'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Rp0'), findsNothing);

    costs.add({'kopi': const ProductCost(productId: 'kopi', hpp: 30000)});
    await tester.pump();
    await tester.pump();
    expect(find.text('Memuat…'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Rp300.000'), findsWidgets); // 10 × 30.000
  });
}
