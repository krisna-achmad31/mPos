import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/product.dart';
import '../../product_providers.dart';
import '../../../reports/domain/demo_catalog.dart';
import '../../../stock/domain/entities/stock_receipt.dart';
import '../../../stock/stock_providers.dart';

/// Kata kunci pencarian di daftar produk.
class ProductSearchViewModel extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final productSearchProvider = NotifierProvider<ProductSearchViewModel, String>(ProductSearchViewModel.new);

/// Filter halaman Produk Owner: hanya yang perlu restock, dan/atau satu kategori.
class ProductFilter {
  const ProductFilter({this.restockOnly = false, this.category});

  final bool restockOnly;
  final String? category;
}

class ProductFilterViewModel extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void toggleRestock() => state = ProductFilter(restockOnly: !state.restockOnly, category: state.category);

  void setCategory(String? category) => state = ProductFilter(restockOnly: state.restockOnly, category: category);
}

final productFilterProvider = NotifierProvider<ProductFilterViewModel, ProductFilter>(ProductFilterViewModel.new);

/// Kategori yang ada, urut abjad.
final productCategoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).value ?? const [];
  return products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
});

/// Daftar produk setelah pencarian & filter; produk perlu restock selalu di atas.
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(productSearchProvider);
  final filter = ref.watch(productFilterProvider);
  return ref.watch(productsProvider).whenData((products) {
    final list = products
        .where((p) =>
            p.matches(query) &&
            (!filter.restockOnly || (p.active && p.needsReorder)) &&
            (filter.category == null || p.category == filter.category))
        .toList();
    list.sort((a, b) {
      if (a.needsReorder != b.needsReorder) return a.needsReorder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  });
});

final reorderProductsProvider = Provider<AsyncValue<List<Product>>>(
  (ref) => ref.watch(productsProvider).whenData((list) => list.where((p) => p.active && p.needsReorder).toList()),
);

class ProductFormViewModel extends ActionViewModel {
  Future<bool> save(Product product, {required int buyPrice}) => run(() async {
        if (product.name.trim().isEmpty) throw const AppException('Nama produk wajib diisi.');
        if (product.sellPrice <= 0) throw const AppException('Harga jual harus lebih dari 0.');
        if (product.wholesalePrice > 0 && product.wholesaleMinQty < 2) {
          throw const AppException('Qty minimal grosir minimal 2.');
        }
        if (product.wholesalePrice >= product.sellPrice && product.wholesalePrice > 0) {
          throw const AppException('Harga grosir harus lebih murah dari harga satuan.');
        }
        if (product.minStock < 0) throw const AppException('Stok minimum tidak boleh negatif.');
        for (final pack in product.packs) {
          if (pack.price > pack.contents * product.sellPrice) {
            throw AppException('Harga per ${pack.name} lebih mahal dari harga satuan × isi '
                '(${pack.contents} × ${product.sellPrice}).');
          }
        }
        final sizes = product.packs.map((p) => p.contents).toList();
        if (sizes.toSet().length != sizes.length) throw const AppException('Isi tiap kemasan harus berbeda.');
        final user = ref.read(currentUserProvider);
        await ref.read(productRepositoryProvider).saveProduct(product, buyPrice: buyPrice, userId: user.uid);
      });

  Future<bool> setActive(Product product, bool active) =>
      run(() => ref.read(productRepositoryProvider).setActive(product.id, active));
}

final productFormViewModelProvider =
    NotifierProvider<ProductFormViewModel, AsyncValue<void>>(ProductFormViewModel.new);

/// Memasukkan / menyinkronkan katalog contoh distributor cafe ke produk asli.
class SampleProductsViewModel extends ActionViewModel {
  /// Mengembalikan (produk baru, produk diperbarui).
  Future<(int created, int updated)?> addCafeSamples() async {
    var result = (0, 0);
    final ok = await run(() async {
      final user = ref.read(currentUserProvider);
      final seeds = DemoCatalog.seedProducts;
      final created = await ref
          .read(productRepositoryProvider)
          .upsertCatalogProducts([for (final s in seeds) (product: s.product, buyPrice: s.buyPrice)]);
      final fresh = seeds.where((s) => created.contains(s.product.id)).toList();
      if (fresh.isNotEmpty) {
        // Stok awal hanya untuk produk yang baru dibuat.
        await ref.read(stockRepositoryProvider).createReceipt(
              StockReceipt(
                id: '',
                supplier: 'Stok awal (produk contoh)',
                docNo: 'CONTOH-CAFE',
                date: DateTime.now(),
                items: [
                  for (final s in fresh)
                    StockReceiptItem(
                      productId: s.product.id,
                      productName: s.product.name,
                      qty: s.initialStock,
                      buyPrice: s.buyPrice,
                    ),
                ],
              ),
              user,
            );
      }
      result = (created.length, seeds.length - created.length);
    });
    return ok ? result : null;
  }
}

final sampleProductsViewModelProvider =
    NotifierProvider<SampleProductsViewModel, AsyncValue<void>>(SampleProductsViewModel.new);
