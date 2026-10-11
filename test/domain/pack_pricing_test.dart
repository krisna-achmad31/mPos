import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/pricing/domain/entities/discount.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/products/domain/entities/product.dart';
import 'package:mpos/features/sales/domain/services/cart_rules.dart';

void main() {
  // Sirup: Rp100.000/botol, karton isi 20 = Rp1.800.000.
  const sirup = Product(
    id: 'sirup',
    name: 'Sirup Vanilla',
    unit: 'botol',
    sellPrice: 100000,
    stock: 500,
    packs: [ProductPack(name: 'karton', contents: 20, price: 1800000)],
  );

  test('25 botol = 1 karton + 5 botol, harga karton + 5 x harga satuan', () {
    final lines = CartRules.addItem([], sirup, qty: 25);
    final line = lines.single;
    expect(line.packs.single.count, 1);
    expect(line.looseQty, 5);
    expect(line.gross, 1800000 + 5 * 100000);
    expect(line.priceType, PriceType.pack);
    expect(line.breakdownLabel, '1 karton (isi 20) + 5 botol');
  });

  test('menambah qty memecah ulang otomatis (19 → 20 = pas 1 karton)', () {
    var lines = CartRules.addItem([], sirup, qty: 19);
    expect(lines.single.packs, isEmpty);
    expect(lines.single.gross, 1900000);
    lines = CartRules.addItem(lines, sirup, qty: 1);
    expect(lines.single.packs.single.count, 1);
    expect(lines.single.looseQty, 0);
    expect(lines.single.gross, 1800000);
  });

  test('beberapa kemasan: isi terbesar dulu', () {
    const cup = Product(
      id: 'cup',
      name: 'Cup',
      unit: 'pcs',
      sellPrice: 700,
      stock: 100000,
      packs: [
        ProductPack(name: 'pouch', contents: 50, price: 32000),
        ProductPack(name: 'karton', contents: 1000, price: 600000),
      ],
    );
    final line = CartRules.addItem([], cup, qty: 1075).single;
    expect(line.breakdownLabel, '1 karton (isi 1000) + 1 pouch (isi 50) + 25 pcs');
    expect(line.gross, 600000 + 32000 + 25 * 700);
  });

  test('diskon persen dihitung dari nilai baris sebenarnya (setelah harga karton)', () {
    const promo = Discount(id: 'p', name: 'p', kind: DiscountKind.promo, type: DiscountType.percent, value: 10);
    final lines = CartRules.addItem([], sirup, qty: 25);
    final priced = CartRules.applyDiscounts(lines, customerId: null, discounts: [promo], now: DateTime(2026));
    expect(priced.single.discountAmount, 230000);
  });
}
