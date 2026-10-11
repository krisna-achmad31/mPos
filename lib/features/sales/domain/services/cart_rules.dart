import '../../../../core/error/app_exception.dart';
import '../../../pricing/domain/entities/discount.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../products/domain/entities/product.dart';
import '../entities/cart_line.dart';

/// Aturan keranjang yang sama untuk kasir (Owner) dan aplikasi Customer.
abstract final class CartRules {
  static int qtyInCart(List<CartLine> lines, String productId, {int? exceptIndex}) {
    var total = 0;
    for (var i = 0; i < lines.length; i++) {
      if (i != exceptIndex && lines[i].productId == productId) total += lines[i].qty;
    }
    return total;
  }

  /// Sisa qty yang masih bisa ditambahkan, memperhitungkan isi keranjang.
  static int remainingStock(List<CartLine> lines, Product product) {
    if (!product.trackStock) return 1 << 30;
    final left = product.stock - qtyInCart(lines, product.id);
    return left < 0 ? 0 : left;
  }

  /// Menambah produk. Produk + harga yang sama digabung; harga manual berbeda jadi baris baru.
  /// Stok dicek kumulatif (perbaikan dari aplikasi Excel).
  static List<CartLine> addItem(List<CartLine> lines, Product product, {int qty = 1, int? manualPrice}) {
    if (qty <= 0) throw const AppException('Qty harus lebih dari 0.');
    if (manualPrice != null && manualPrice <= 0) throw const AppException('Harga manual harus lebih dari 0.');
    _ensureStock(product, qtyInCart(lines, product.id) + qty);

    final result = [...lines];
    if (manualPrice != null) {
      final index = result.indexWhere(
          (l) => l.productId == product.id && l.priceType == PriceType.manual && l.unitPrice == manualPrice);
      if (index >= 0) {
        result[index] = result[index].copyWith(qty: result[index].qty + qty);
      } else {
        result.add(_line(product, qty, manualPrice, PriceType.manual));
      }
      return result;
    }

    final index = result.indexWhere((l) => l.productId == product.id && l.priceType != PriceType.manual);
    if (index >= 0) {
      final newQty = result[index].qty + qty;
      final (price, type) = PricingService.autoPrice(product, newQty);
      result[index] = result[index].copyWith(qty: newQty, unitPrice: price, priceType: type);
    } else {
      final (price, type) = PricingService.autoPrice(product, qty);
      result.add(_line(product, qty, price, type));
    }
    return result;
  }

  /// Mengubah qty satu baris. qty 0 menghapus baris.
  static List<CartLine> setQty(List<CartLine> lines, int index, int qty, Product product) {
    if (qty <= 0) return [...lines]..removeAt(index);
    _ensureStock(product, qtyInCart(lines, product.id, exceptIndex: index) + qty);
    final line = lines[index];
    final result = [...lines];
    if (line.priceType == PriceType.manual) {
      result[index] = line.copyWith(qty: qty);
    } else {
      final (price, type) = PricingService.autoPrice(product, qty);
      result[index] = line.copyWith(qty: qty, unitPrice: price, priceType: type);
    }
    return result;
  }

  /// Untuk Customer: qty yang diminta dipotong ke stok tersedia, bukan ditolak.
  static (List<CartLine> lines, int addedQty) addClamped(List<CartLine> lines, Product product, int qty) {
    final allowed = qty.clamp(0, remainingStock(lines, product));
    if (allowed == 0) return (lines, 0);
    return (addItem(lines, product, qty: allowed), allowed);
  }

  /// Menerapkan harga khusus / promo terbesar ke setiap baris (dipakai Owner saat membuat nota).
  static List<CartLine> applyDiscounts(
    List<CartLine> lines, {
    required String? customerId,
    required Iterable<Discount> discounts,
    required DateTime now,
  }) {
    return [
      for (final line in lines)
        () {
          final best = line.priceType == PriceType.manual
              ? null
              : PricingService.bestDiscount(
                  productId: line.productId,
                  customerId: customerId,
                  unitPrice: line.unitPrice,
                  qty: line.qty,
                  discounts: discounts,
                  now: now,
                );
          return best == null
              ? line.withoutDiscount()
              : line.copyWith(
                  discountAmount: best.amount,
                  discountId: best.discount.id,
                  discountLabel: best.discount.kind == DiscountKind.special ? 'Diskon pelanggan' : best.discount.name,
                );
        }(),
    ];
  }

  static void _ensureStock(Product product, int requested) {
    if (product.trackStock && requested > product.stock) {
      throw AppException('Stok ${product.name} tersedia hanya ${product.stock} ${product.unit}.');
    }
  }

  static CartLine _line(Product p, int qty, int price, PriceType type) => CartLine(
        productId: p.id,
        name: p.name,
        unit: p.unit,
        qty: qty,
        unitPrice: price,
        priceType: type,
        trackStock: p.trackStock,
      );
}
