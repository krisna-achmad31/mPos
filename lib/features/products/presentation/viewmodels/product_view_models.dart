import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/product.dart';
import '../../product_providers.dart';

/// Kata kunci pencarian di daftar produk.
class ProductSearchViewModel extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final productSearchProvider = NotifierProvider<ProductSearchViewModel, String>(ProductSearchViewModel.new);

/// Daftar produk yang sudah difilter pencarian, produk perlu order ulang di atas.
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(productSearchProvider);
  return ref.watch(productsProvider).whenData((products) {
    final list = products.where((p) => p.matches(query)).toList();
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
        final user = ref.read(currentUserProvider);
        await ref.read(productRepositoryProvider).saveProduct(product, buyPrice: buyPrice, userId: user.uid);
      });

  Future<bool> setActive(Product product, bool active) =>
      run(() => ref.read(productRepositoryProvider).setActive(product.id, active));
}

final productFormViewModelProvider =
    NotifierProvider<ProductFormViewModel, AsyncValue<void>>(ProductFormViewModel.new);
