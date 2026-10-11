import '../entities/discount.dart';

abstract interface class DiscountRepository {
  /// Semua diskon (hanya Owner).
  Stream<List<Discount>> watchAll();

  /// Promo publik yang boleh terlihat Customer di katalog.
  Stream<List<Discount>> watchCatalogPromos();

  Future<void> save(Discount discount);

  Future<void> setActive(String id, bool active);
}
