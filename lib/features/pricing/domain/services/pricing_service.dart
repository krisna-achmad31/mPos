import '../../../products/domain/entities/product.dart';
import '../entities/discount.dart';

enum PriceType {
  retail('Satuan'),
  wholesale('Grosir'),
  manual('Manual');

  const PriceType(this.label);

  final String label;
}

class AppliedDiscount {
  const AppliedDiscount({required this.discount, required this.amount});

  final Discount discount;
  final int amount;
}

/// Aturan harga murni (tanpa Firebase) agar bisa dites.
abstract final class PricingService {
  /// Harga otomatis: grosir bila qty mencapai minimal grosir, selain itu harga satuan.
  static (int price, PriceType type) autoPrice(Product product, int qty) {
    if (product.hasWholesale && qty >= product.wholesaleMinQty) {
      return (product.wholesalePrice, PriceType.wholesale);
    }
    return (product.sellPrice, PriceType.retail);
  }

  /// Memilih potongan TERBESAR yang berlaku (tidak ditumpuk).
  static AppliedDiscount? bestDiscount({
    required String productId,
    required String? customerId,
    required int unitPrice,
    required int qty,
    required Iterable<Discount> discounts,
    required DateTime now,
  }) {
    AppliedDiscount? best;
    for (final d in discounts) {
      if (!d.isValidAt(now) || !d.appliesTo(productId: productId, customerId: customerId)) continue;
      final amount = d.amountFor(unitPrice: unitPrice, qty: qty);
      if (amount > 0 && (best == null || amount > best.amount)) {
        best = AppliedDiscount(discount: d, amount: amount);
      }
    }
    return best;
  }

  /// Harga coret di katalog: hanya promo publik yang ditandai tampil.
  static int? catalogPromoPrice(Product product, Iterable<Discount> discounts, DateTime now) {
    final visible = discounts.where((d) => d.visibleInCatalog && d.kind == DiscountKind.promo && d.customerId == null);
    final best = bestDiscount(
      productId: product.id,
      customerId: null,
      unitPrice: product.sellPrice,
      qty: 1,
      discounts: visible,
      now: now,
    );
    return best == null ? null : product.sellPrice - best.amount;
  }
}
