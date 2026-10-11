import '../entities/discount.dart';

abstract interface class DiscountRepository {
  /// Semua diskon (hanya Owner).
  Stream<List<Discount>> watchAll();

  /// Promo yang boleh terlihat [customerId] di katalog (publik + khusus akun itu).
  Stream<List<Discount>> watchCatalogPromos(String customerId);

  Future<void> save(Discount discount);

  Future<void> setActive(String id, bool active);
}
