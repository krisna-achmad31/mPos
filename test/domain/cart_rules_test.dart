import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/pricing/domain/entities/discount.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/sales/domain/services/cart_rules.dart';

import '../helpers.dart';

void main() {
  group('addItem', () {
    test('menggabungkan produk yang sama menjadi satu baris', () {
      final p = product();
      var lines = CartRules.addItem([], p, qty: 2);
      lines = CartRules.addItem(lines, p, qty: 3);
      expect(lines, hasLength(1));
      expect(lines.single.qty, 5);
    });

    test('cek stok kumulatif: isi keranjang ikut dihitung (bug Excel)', () {
      final p = product(stock: 5);
      final lines = CartRules.addItem([], p, qty: 4);
      expect(() => CartRules.addItem(lines, p, qty: 2), throwsA(isA<AppException>()));
    });

    test('produk tanpa stok tidak dicek stoknya', () {
      final jasa = product(stock: 0, trackStock: false);
      expect(CartRules.addItem([], jasa, qty: 100).single.qty, 100);
    });

    test('harga grosir berlaku otomatis saat qty mencapai minimal', () {
      final p = product(price: 20000, wholesalePrice: 18000, wholesaleMinQty: 10, stock: 50);
      var lines = CartRules.addItem([], p, qty: 9);
      expect(lines.single.priceType, PriceType.retail);
      lines = CartRules.addItem(lines, p, qty: 1);
      expect(lines.single.unitPrice, 18000);
      expect(lines.single.priceType, PriceType.wholesale);
    });

    test('harga manual berbeda jadi baris baru, harga manual sama digabung', () {
      final p = product();
      var lines = CartRules.addItem([], p, qty: 1);
      lines = CartRules.addItem(lines, p, qty: 1, manualPrice: 15000);
      lines = CartRules.addItem(lines, p, qty: 1, manualPrice: 15000);
      expect(lines, hasLength(2));
      expect(lines[1].qty, 2);
    });
  });

  test('setQty menolak bila total qty melebihi stok', () {
    final p = product(stock: 3);
    final lines = CartRules.addItem([], p, qty: 1);
    expect(() => CartRules.setQty(lines, 0, 4, p), throwsA(isA<AppException>()));
    expect(CartRules.setQty(lines, 0, 0, p), isEmpty);
  });

  test('addClamped memotong qty Customer ke stok tersedia', () {
    final p = product(stock: 3);
    final (lines, added) = CartRules.addClamped([], p, 10);
    expect(added, 3);
    expect(lines.single.qty, 3);
    final (_, again) = CartRules.addClamped(lines, p, 1);
    expect(again, 0);
  });

  group('applyDiscounts', () {
    final now = DateTime(2026, 10, 11);
    const special = Discount(
      id: 'd1',
      name: 'Toko A',
      kind: DiscountKind.special,
      type: DiscountType.percent,
      value: 10,
      customerId: 'tokoA',
    );

    test('harga khusus hanya untuk customer yang dipilih, berlabel Diskon pelanggan', () {
      final lines = CartRules.addItem([], product(), qty: 10);
      final forA = CartRules.applyDiscounts(lines, customerId: 'tokoA', discounts: [special], now: now);
      final forB = CartRules.applyDiscounts(lines, customerId: 'tokoB', discounts: [special], now: now);
      expect(forA.single.discountAmount, 20000);
      expect(forA.single.discountLabel, 'Diskon pelanggan');
      expect(forB.single.discountAmount, 0);
    });

    test('baris harga manual tidak diberi diskon lagi', () {
      final lines = CartRules.addItem([], product(), qty: 1, manualPrice: 15000);
      final priced = CartRules.applyDiscounts(lines, customerId: 'tokoA', discounts: [special], now: now);
      expect(priced.single.discountAmount, 0);
    });
  });
}
