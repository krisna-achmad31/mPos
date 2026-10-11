import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/pricing/domain/entities/discount.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';

import '../helpers.dart';

void main() {
  final now = DateTime(2026, 10, 11);

  Discount promo({
    String id = 'x',
    double value = 10,
    DiscountType type = DiscountType.percent,
    String? productId,
    String? customerId,
    bool visible = false,
    DateTime? start,
    DateTime? end,
    bool active = true,
  }) =>
      Discount(
        id: id,
        name: id,
        kind: DiscountKind.promo,
        type: type,
        value: value,
        productId: productId,
        customerId: customerId,
        visibleInCatalog: visible,
        start: start,
        end: end,
        active: active,
      );

  test('memakai potongan terbesar, tidak ditumpuk', () {
    final best = PricingService.bestDiscount(
      productId: 'p1',
      customerId: 'c1',
      unitPrice: 20000,
      qty: 10,
      discounts: [promo(id: 'a', value: 5), promo(id: 'b', value: 1500, type: DiscountType.amount)],
      now: now,
    );
    expect(best!.discount.id, 'b');
    expect(best.amount, 15000);
  });

  test('promo di luar periode atau nonaktif diabaikan', () {
    final result = PricingService.bestDiscount(
      productId: 'p1',
      customerId: null,
      unitPrice: 20000,
      qty: 1,
      discounts: [
        promo(end: DateTime(2026, 10, 1)),
        promo(start: DateTime(2026, 11, 1)),
        promo(active: false),
      ],
      now: now,
    );
    expect(result, isNull);
  });

  test('promo item + akun hanya berlaku bila keduanya cocok', () {
    final d = promo(productId: 'p1', customerId: 'c1');
    expect(d.appliesTo(productId: 'p1', customerId: 'c1'), isTrue);
    expect(d.appliesTo(productId: 'p1', customerId: 'c2'), isFalse);
    expect(d.appliesTo(productId: 'p2', customerId: 'c1'), isFalse);
  });

  test('potongan tidak melebihi nilai baris', () {
    expect(promo(value: 50000, type: DiscountType.amount).amountFor(unitPrice: 20000, qty: 1), 20000);
  });

  test('katalog: promo tampil hanya untuk pelanggan yang dituju', () {
    final p = product();
    expect(PricingService.catalogPromoPrice(p, [promo(visible: false)], now), isNull);
    expect(PricingService.catalogPromoPrice(p, [promo(visible: true)], now), 18000);
    final forC1 = [promo(visible: true, customerId: 'c1')];
    expect(PricingService.catalogPromoPrice(p, forC1, now, customerId: 'c1'), 18000);
    expect(PricingService.catalogPromoPrice(p, forC1, now, customerId: 'c2'), isNull);
  });
}
