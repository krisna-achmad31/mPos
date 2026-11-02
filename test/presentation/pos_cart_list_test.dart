import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/pricing/pricing_providers.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/sales/presentation/viewmodels/pos_view_model.dart';
import 'package:mpos/features/sales/presentation/views/pos_view.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';
import 'package:mpos/features/settings/settings_providers.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  const product = Product(id: 'p1', name: 'Fanta', sellPrice: 85000, stock: 10);

  for (final size in [const Size(1600, 1000), const Size(600, 1200)]) {
    testWidgets('baris keranjang tampil di kasir (${size.width.toInt()}px)', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          productsProvider.overrideWith((ref) => Stream.value(const [product])),
          discountsProvider.overrideWith((ref) => Stream.value(const [])),
          storeSettingsProvider.overrideWith(
            (ref) => Stream.value(const StoreSettings()),
          ),
          customersProvider.overrideWith((ref) => Stream.value(const [])),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: PosView())),
        ),
      );
      await tester.pumpAndSettle();
      container.read(posViewModelProvider.notifier).addProduct(product);
      await tester.pumpAndSettle();
      expect(find.text('Fanta'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}
