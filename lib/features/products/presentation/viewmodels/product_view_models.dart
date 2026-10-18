import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/bundle_rules.dart';
import '../../domain/services/inventory_summary.dart';
import '../../domain/services/price_suggestion.dart';
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

/// Filter stok di halaman Produk Owner.
enum StockFilter {
  all('Semua stok'),
  safe('Aman'),
  low('Menipis'),
  out('Habis'),

  /// Menipis + habis (dari banner restock).
  restock('Perlu restock');

  const StockFilter(this.label);

  final String label;

  bool accepts(Product p) => switch (this) {
        all => true,
        safe => StockLevel.of(p) == StockLevel.safe,
        low => StockLevel.of(p) == StockLevel.low,
        out => StockLevel.of(p) == StockLevel.out,
        restock => p.active && p.needsReorder,
      };
}

enum ProductTypeFilter {
  all('Semua jenis'),
  product('Produk'),
  bundle('Bundling');

  const ProductTypeFilter(this.label);

  final String label;
}

enum ActiveFilter {
  all('Semua status'),
  active('Aktif'),
  inactive('Nonaktif');

  const ActiveFilter(this.label);

  final String label;
}

enum ProductSort {
  restockFirst('Perlu restock dulu'),
  name('Nama A–Z'),
  stockAsc('Stok tersedikit'),
  stockDesc('Stok terbanyak'),
  valueDesc('Nilai barang tertinggi'),
  priceDesc('Harga satuan tertinggi');

  const ProductSort(this.label);

  final String label;
}

/// Filter halaman Produk Owner: stok, kategori, jenis (produk / bundling), status, dan urutan.
class ProductFilter {
  const ProductFilter({
    this.stock = StockFilter.all,
    this.category,
    this.type = ProductTypeFilter.all,
    this.status = ActiveFilter.all,
    this.sort = ProductSort.restockFirst,
  });

  final StockFilter stock;
  final String? category;
  final ProductTypeFilter type;
  final ActiveFilter status;
  final ProductSort sort;

  bool get restockOnly => stock == StockFilter.restock;

  bool get isFiltered =>
      stock != StockFilter.all || category != null || type != ProductTypeFilter.all || status != ActiveFilter.all;

  ProductFilter copyWith({
    StockFilter? stock,
    String? Function()? category,
    ProductTypeFilter? type,
    ActiveFilter? status,
    ProductSort? sort,
  }) =>
      ProductFilter(
        stock: stock ?? this.stock,
        category: category != null ? category() : this.category,
        type: type ?? this.type,
        status: status ?? this.status,
        sort: sort ?? this.sort,
      );

  bool accepts(Product p) =>
      stock.accepts(p) &&
      (category == null || p.category == category) &&
      switch (type) {
        ProductTypeFilter.all => true,
        ProductTypeFilter.product => !p.isBundle,
        ProductTypeFilter.bundle => p.isBundle,
      } &&
      switch (status) {
        ActiveFilter.all => true,
        ActiveFilter.active => p.active,
        ActiveFilter.inactive => !p.active,
      };
}

class ProductFilterViewModel extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => const ProductFilter();

  void toggleRestock() =>
      state = state.copyWith(stock: state.restockOnly ? StockFilter.all : StockFilter.restock);

  void setStock(StockFilter stock) => state = state.copyWith(stock: stock);

  void setCategory(String? category) => state = state.copyWith(category: () => category);

  void setType(ProductTypeFilter type) => state = state.copyWith(type: type);

  void setStatus(ActiveFilter status) => state = state.copyWith(status: status);

  void setSort(ProductSort sort) => state = state.copyWith(sort: sort);

  void reset() => state = ProductFilter(sort: state.sort);
}

final productFilterProvider = NotifierProvider<ProductFilterViewModel, ProductFilter>(ProductFilterViewModel.new);

/// Tampilan daftar produk Owner: kartu atau tabel (seperti Excel).
enum ProductViewMode { cards, table }

class ProductViewModeViewModel extends Notifier<ProductViewMode> {
  @override
  ProductViewMode build() => ProductViewMode.cards;

  void set(ProductViewMode mode) => state = mode;
}

final productViewModeProvider =
    NotifierProvider<ProductViewModeViewModel, ProductViewMode>(ProductViewModeViewModel.new);

/// Kategori yang ada, urut abjad.
final productCategoriesProvider = Provider<List<String>>((ref) {
  final products = ref.watch(productsProvider).value ?? const [];
  return products.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
});

/// Modal per produk (HPP / harga beli). Kosong sampai data modal terbaca.
final productUnitCostsProvider = Provider<Map<String, ProductCost>>(
  (ref) => ref.watch(productCostsProvider).value ?? const {},
);

/// Daftar produk setelah pencarian, filter, dan urutan.
final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(productSearchProvider);
  final filter = ref.watch(productFilterProvider);
  final costs = ref.watch(productUnitCostsProvider);
  return ref.watch(productsProvider).whenData((products) {
    final list = products.where((p) => p.matches(query) && filter.accepts(p)).toList();
    int byName(Product a, Product b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    int value(Product p) => InventorySummary.valueOf(p, costs[p.id]);
    list.sort((a, b) {
      final c = switch (filter.sort) {
        ProductSort.restockFirst => a.needsReorder == b.needsReorder ? 0 : (a.needsReorder ? -1 : 1),
        ProductSort.name => 0,
        ProductSort.stockAsc => a.stock.compareTo(b.stock),
        ProductSort.stockDesc => b.stock.compareTo(a.stock),
        ProductSort.valueDesc => value(b).compareTo(value(a)),
        ProductSort.priceDesc => b.sellPrice.compareTo(a.sellPrice),
      };
      return c != 0 ? c : byName(a, b);
    });
    return list;
  });
});

/// Total stok & nilai barang seluruh produk (bukan hanya hasil filter).
final inventorySummaryProvider = Provider<InventorySummary?>((ref) {
  final products = ref.watch(productsProvider).value;
  // Tunggu data modal agar nilai barang tidak sempat tampil Rp0.
  if (products == null || !ref.watch(productCostsProvider).hasValue) return null;
  return InventorySummary.of(products, ref.watch(productUnitCostsProvider));
});

/// Total stok & nilai untuk hasil filter saat ini.
final filteredInventorySummaryProvider = Provider<InventorySummary?>((ref) {
  final products = ref.watch(filteredProductsProvider).value;
  if (products == null) return null;
  return InventorySummary.of(products, ref.watch(productUnitCostsProvider));
});

final reorderProductsProvider = Provider<AsyncValue<List<Product>>>(
  (ref) => ref.watch(productsProvider).whenData((list) => list.where((p) => p.active && p.needsReorder).toList()),
);

class ProductFormViewModel extends ActionViewModel {
  Future<bool> save(Product product, {required int buyPrice}) => run(() async {
        if (product.name.trim().isEmpty) throw const AppException('Nama produk wajib diisi.');
        final taken = BarcodeRules.owner(await readReady(productsProvider.future), product.barcode, excludeId: product.id);
        if (taken != null) throw AppException(barcodeTakenMessage(taken));
        if (product.isBundle) {
          BundleRules.validate(product);
          final user = ref.read(currentUserProvider);
          await ref.read(productRepositoryProvider).saveProduct(product, buyPrice: buyPrice, userId: user.uid);
          return;
        }
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

String barcodeTakenMessage(Product taken) => 'Barcode ${taken.barcode} sudah dipakai "${taken.name}". '
    'Barang yang sama (walau harga beli berbeda) ditambah lewat Stok Masuk agar HPP-nya dirata-rata.';

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
