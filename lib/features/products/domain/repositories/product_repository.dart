import '../entities/product.dart';

abstract interface class ProductRepository {
  Stream<List<Product>> watchProducts({bool activeOnly = false});

  Stream<Product?> watchProduct(String id);

  Future<ProductCost?> getCost(String productId);

  Stream<Map<String, ProductCost>> watchCosts();

  /// Membuat produk baru bila [Product.id] kosong. Mengembalikan id produk.
  /// Perubahan harga jual dicatat ke riwayat harga.
  Future<String> saveProduct(Product product, {required int buyPrice, required String userId});

  Future<void> setActive(String id, bool active);
}
