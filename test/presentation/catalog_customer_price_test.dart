import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/utils/money.dart';
import 'package:mpos/features/auth/auth_providers.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/catalog/presentation/views/catalog_view.dart';
import 'package:mpos/features/catalog/presentation/viewmodels/customer_cart_view_model.dart';
import 'package:mpos/features/pricing/pricing_providers.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/presentation/viewmodels/product_view_models.dart';
import 'package:mpos/features/products/product_providers.dart';

void main() {
  Future<ProviderContainer> show(WidgetTester tester, int? specialPrice) async {
    final product = Product(
      id: 'fanta',
      name: 'Fanta',
      sellPrice: 7000,
      stock: 20,
      customerPrices: specialPrice == null ? const {} : {'c1': specialPrice},
    );
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          const AppUser(uid: 'c1', name: 'Toko A', email: '', role: UserRole.customer),
        ),
        activeProductsProvider.overrideWith((ref) => Stream.value([product])),
        productCategoriesProvider.overrideWith((ref) => const []),
        catalogPromosProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CatalogView()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('harga khusus lebih rendah tampil dengan harga normal dicoret', (tester) async {
    final container = await show(tester, 5000);
    final normal = tester.widget<Text>(find.text(formatRupiah(7000)));
    expect(normal.style?.decoration, TextDecoration.lineThrough);
    expect(find.text(formatRupiah(5000)), findsOneWidget);
    expect(find.textContaining('khusus toko'), findsNothing);
    await tester.ensureVisible(find.text('Tambah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(container.read(customerCartViewModelProvider('c1')).lines.single.unitPrice, 5000);
  });

  testWidgets('harga lebih tinggi tidak ditampilkan sebagai diskon', (tester) async {
    await show(tester, 8000);
    expect(find.text(formatRupiah(7000)), findsNothing);
    final price = tester.widget<Text>(find.text(formatRupiah(8000)));
    expect(price.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets('produk tanpa harga khusus tetap memakai harga normal', (tester) async {
    await show(tester, null);
    final price = tester.widget<Text>(find.text(formatRupiah(7000)));
    expect(price.style?.decoration, isNot(TextDecoration.lineThrough));
  });
}
