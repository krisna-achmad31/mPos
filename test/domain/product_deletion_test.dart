import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/domain/repositories/product_repository.dart';
import 'package:mpos/features/products/presentation/viewmodels/product_view_models.dart';
import 'package:mpos/features/products/product_providers.dart';

class _ProductRepository extends Mock implements ProductRepository {}

void main() {
  const product = Product(id: 'fanta', name: 'Fanta', sellPrice: 5000);

  Future<ProviderContainer> setup(WidgetTester tester, _ProductRepository repository, List<Product> products) async {
    final container = ProviderContainer(
      overrides: [
        productRepositoryProvider.overrideWithValue(repository),
        productsProvider.overrideWith((ref) => Stream.value(products)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(productsProvider, (_, _) {});
    await tester.pump();
    return container;
  }

  testWidgets('produk stok kosong diteruskan ke repository', (tester) async {
    final repository = _ProductRepository();
    when(() => repository.deleteProduct(product.id)).thenAnswer((_) async {});
    final container = await setup(tester, repository, [product]);
    expect(await container.read(productFormViewModelProvider.notifier).deleteProduct(product), isTrue);
    verify(() => repository.deleteProduct(product.id)).called(1);
  });

  testWidgets('stok positif dan negatif tidak boleh dihapus', (tester) async {
    final repository = _ProductRepository();
    final container = await setup(tester, repository, [product]);
    for (final stock in [1, -1]) {
      expect(
        await container.read(productFormViewModelProvider.notifier).deleteProduct(product.copyWith(stock: stock)),
        isFalse,
      );
    }
    verifyNever(() => repository.deleteProduct(any()));
  });

  testWidgets('produk dalam bundling harus dikeluarkan dahulu', (tester) async {
    final repository = _ProductRepository();
    final bundle = Product(
      id: 'bundle',
      name: 'Paket Fanta',
      sellPrice: 10000,
      bundleItems: const [BundleItem(productId: 'fanta', name: 'Fanta', qty: 2)],
    );
    final container = await setup(tester, repository, [product, bundle]);
    expect(await container.read(productFormViewModelProvider.notifier).deleteProduct(product), isFalse);
    expect('${container.read(productFormViewModelProvider).error}', contains('Paket Fanta'));
    verifyNever(() => repository.deleteProduct(any()));
  });
}
