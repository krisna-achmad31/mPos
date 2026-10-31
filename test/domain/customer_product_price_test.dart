import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/catalog/presentation/viewmodels/customer_cart_view_model.dart';
import 'package:mpos/features/pricing/pricing_providers.dart';
import 'package:mpos/features/products/data/models/product_model.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/products/product_providers.dart';
import 'package:mpos/features/sales/domain/services/cart_rules.dart';
import 'package:mpos/features/sales/presentation/viewmodels/pos_view_model.dart';

void main() {
  const product = Product(
    id: 'fanta',
    name: 'Fanta',
    sellPrice: 7000,
    stock: 100,
    wholesalePrice: 6000,
    wholesaleMinQty: 10,
    packs: [ProductPack(name: 'karton', contents: 12, price: 65000)],
    customerPrices: {'toko-a': 5000, 'toko-b': 8000},
  );

  test('harga toko tersimpan dan produk lama tetap kompatibel', () {
    final restored = ProductModel.fromMap(product.id, ProductModel.toEditableMap(product));
    expect(restored.customerPrices, product.customerPrices);
    expect(restored.copyWith(name: 'Baru').customerPrices, product.customerPrices);
    expect(ProductModel.fromMap('old', {}).customerPrices, isEmpty);
  });

  test('harga khusus berlaku per satuan, termasuk qty grosir dan kemasan', () {
    final line = CartRules.addItem([], product.forCustomer('toko-a'), qty: 13).single;
    expect(line.gross, 65000);
    expect(line.packs, isEmpty);
    expect(product.forCustomer(null).sellPrice, 7000);
    expect(product.forCustomer('other').packs, product.packs);
    expect(product.forCustomer('toko-b').sellPrice, 8000);
  });

  test('ganti toko menghitung ulang harga, kembali umum memulihkan kemasan', () {
    final normal = CartRules.addItem([], product, qty: 13).single;
    final special = CartRules.reprice(normal, product.forCustomer('toko-a'));
    expect(special.gross, 65000);
    expect(CartRules.reprice(special, product).gross, normal.gross);
    final manual = CartRules.addItem([], product, manualPrice: 4000).single;
    expect(CartRules.reprice(manual, product.forCustomer('toko-b')).unitPrice, 4000);
  });

  test('keranjang pelanggan menerapkan harga toko saat tambah dan ubah qty', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(customerCartViewModelProvider('toko-a').notifier);
    cart.add(product, 2);
    expect(container.read(customerCartViewModelProvider('toko-a')).subtotal, 10000);
    cart.setQty(0, 13, product);
    expect(container.read(customerCartViewModelProvider('toko-a')).subtotal, 65000);
  });

  testWidgets('kasir mengikuti toko terpilih dan memulihkan harga umum', (tester) async {
    final container = ProviderContainer(
      overrides: [
        productsProvider.overrideWith((ref) => Stream.value(const [product])),
        discountsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);
    container.listen(productsProvider, (_, _) {});
    container.listen(discountsProvider, (_, _) {});
    await tester.pump();
    expect(container.read(productsProvider).hasValue, isTrue);
    final pos = container.read(posViewModelProvider.notifier);
    pos.addProduct(product, qty: 13);
    final normal = pos.pricedLines().single.gross;
    pos.setCustomer(const AppUser(uid: 'toko-a', name: 'A', email: '', role: UserRole.customer));
    expect(pos.pricedLines().single.gross, 65000);
    pos.setCustomer(const AppUser(uid: 'toko-b', name: 'B', email: '', role: UserRole.customer));
    expect(pos.pricedLines().single.gross, 104000);
    pos.setCustomer(null);
    expect(pos.pricedLines().single.gross, normal);
  });
}
