import '../../../products/domain/entities/product.dart';
import '../../../sales/domain/entities/cart_line.dart';
import '../entities/discount.dart';

enum PriceType {
  retail('Satuan'),
  wholesale('Grosir'),

  /// Sebagian / seluruh qty dihitung per kemasan (karton, bal, sak).
  pack('Kemasan'),
  manual('Manual');

  const PriceType(this.label);

  final String label;
}

class AppliedDiscount {
  const AppliedDiscount({required this.discount, required this.amount});

  final Discount discount;
  final int amount;
}

class LinePrice {
  const LinePrice({required this.unitPrice, required this.type, required this.packs});

  /// Harga per satuan dasar untuk sisa yang tidak masuk kemasan.
  final int unitPrice;
  final PriceType type;
  final List<PackUsage> packs;
}

/// Aturan harga murni (tanpa Firebase) agar bisa dites.
abstract final class PricingService {
  /// Pecah [qty] ke kemasan terbesar dulu, sisanya per satuan.
  /// Contoh: 25 pcs, karton isi 20 → 1 karton + 5 pcs.
  static LinePrice priceLine(Product product, int qty) {
    var remaining = qty;
    final packs = <PackUsage>[];
    for (final pack in product.packsBySize) {
      final count = remaining ~/ pack.contents;
      if (count > 0) {
        packs.add(PackUsage(name: pack.name, count: count, contents: pack.contents, price: pack.price));
        remaining -= count * pack.contents;
      }
    }
    final (loosePrice, looseType) = autoPrice(product, remaining);
    return LinePrice(unitPrice: loosePrice, type: packs.isEmpty ? looseType : PriceType.pack, packs: packs);
  }

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
    int? gross,
  }) {
    AppliedDiscount? best;
    for (final d in discounts) {
      if (!d.isValidAt(now) || !d.appliesTo(productId: productId, customerId: customerId)) continue;
      final amount = d.amountFor(unitPrice: unitPrice, qty: qty, gross: gross);
      if (amount > 0 && (best == null || amount > best.amount)) {
        best = AppliedDiscount(discount: d, amount: amount);
      }
    }
    return best;
  }

  /// Promo yang boleh terlihat oleh [customerId] di katalog: promo publik + promo khusus akun itu.
  /// Harga khusus (special) tidak pernah tampil di katalog.
  static Iterable<Discount> visiblePromosFor(Iterable<Discount> discounts, String? customerId) => discounts.where(
      (d) => d.visibleInCatalog && d.kind == DiscountKind.promo && (d.customerId == null || d.customerId == customerId));

  /// Harga coret di katalog untuk [customerId].
  static int? catalogPromoPrice(Product product, Iterable<Discount> discounts, DateTime now, {String? customerId}) {
    final visible = visiblePromosFor(discounts, customerId);
    final best = bestDiscount(
      productId: product.id,
      customerId: customerId,
      unitPrice: product.sellPrice,
      qty: 1,
      discounts: visible,
      now: now,
    );
    return best == null ? null : product.sellPrice - best.amount;
  }
}
