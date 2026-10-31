import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/firebase/firebase_providers.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/distributors/domain/distributor.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/presentation/viewmodels/product_export_view_model.dart';
import 'package:mpos/features/products/presentation/viewmodels/product_view_models.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';
import 'package:mpos/features/settings/settings_providers.dart';

void main() {
  testWidgets('ekspor mengambil hasil pencarian dan menunggu profil distributor', (tester) async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith(
          (ref) => Stream.value(const [
            Product(id: 'fanta', name: 'Fanta', sellPrice: 5000),
            Product(id: 'sprite', name: 'Sprite', sellPrice: 7000),
          ]),
        ),
        productCostsProvider.overrideWith(
          (ref) => Stream.value(const {'fanta': ProductCost(productId: 'fanta', buyPrice: 2000)}),
        ),
        storeSettingsProvider.overrideWith(
          (ref) => Stream.value(
            const StoreSettings(storeName: 'Distributor Mitra', address: 'Kediri', phone: '08123456789'),
          ),
        ),
        distributorLogoProvider.overrideWith((ref) => Stream.value(null)),
        currentDistributorProvider.overrideWith((ref) => Stream.value(const Distributor(id: 'd1', name: 'Mitra'))),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 30, 12)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(filteredProductsProvider, (_, _) {});
    await tester.pump();
    container.read(productSearchProvider.notifier).setQuery('fanta');
    final pending = container.read(productExportViewModelProvider.notifier).snapshot();
    await tester.pumpAndSettle();
    final data = await pending;
    expect(data.products.map((p) => p.id), ['fanta']);
    expect(data.unitCost(data.products.single), 2000);
    expect(data.name, 'Distributor Mitra');
    expect(data.settings.address, 'Kediri');
    expect(data.scope, 'Pencarian: fanta');
    expect(data.logoPng, isNull);
    expect(data.exportedAt, DateTime(2026, 10, 30, 12));
  });

  testWidgets('daftar kosong ditolak sebelum membuat file', (tester) async {
    final container = ProviderContainer(
      overrides: [filteredProductsProvider.overrideWith((ref) => const AsyncData([]))],
    );
    addTearDown(container.dispose);
    final ok = await container.read(productExportViewModelProvider.notifier).export(ProductExportFormat.excel);
    expect(ok, isFalse);
    expect('${container.read(productExportViewModelProvider).error}', contains('Tidak ada produk'));
    await tester.pumpAndSettle();
  });
}
