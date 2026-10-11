import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/sales/domain/services/cart_rules.dart';
import 'package:mpos/features/sales/domain/services/invoice_number.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';

import '../helpers.dart';

void main() {
  group('totals', () {
    final lines = CartRules.addItem([], product(price: 10000, stock: 100), qty: 10)
        .map((l) => l.copyWith(discountAmount: 5000))
        .toList();

    test('Subtotal − diskon item − diskon nota + pajak', () {
      final t = SaleCalculator.totals(lines, orderDiscount: const OrderDiscount.amount(5000), taxPercent: 11);
      expect(t.subtotal, 100000);
      expect(t.itemDiscount, 5000);
      expect(t.orderDiscount, 5000);
      expect(t.tax, 9900);
      expect(t.total, 99900);
    });

    test('diskon nota persen dihitung dari nilai setelah diskon item', () {
      final t = SaleCalculator.totals(lines, orderDiscount: const OrderDiscount.percent(10));
      expect(t.orderDiscount, 9500);
      expect(t.total, 85500);
    });
  });

  group('pay', () {
    test('tunai menghasilkan kembalian dan menolak uang kurang', () {
      final r = SaleCalculator.pay(total: 85000, method: PaymentMethod.cash, amount: 100000);
      expect(r.change, 15000);
      expect(r.paid, 85000);
      expect(() => SaleCalculator.pay(total: 85000, method: PaymentMethod.cash, amount: 50000),
          throwsA(isA<AppException>()));
    });

    test('transfer otomatis lunas', () {
      final r = SaleCalculator.pay(total: 85000, method: PaymentMethod.transfer, amount: 0);
      expect(r.statusFor(85000), PaymentStatus.paid);
    });

    test('DP mencatat sisa tagihan', () {
      final r = SaleCalculator.pay(total: 85000, method: PaymentMethod.downPayment, amount: 35000);
      expect(r.remaining, 50000);
      expect(r.statusFor(85000), PaymentStatus.partial);
    });

    test('tempo boleh dibayar 0', () {
      final r = SaleCalculator.pay(total: 85000, method: PaymentMethod.credit, amount: 0);
      expect(r.remaining, 85000);
      expect(r.statusFor(85000), PaymentStatus.unpaid);
    });
  });

  test('nomor nota INV-YYYYMMDD-####', () {
    expect(InvoiceNumber.format(DateTime(2026, 10, 11), 7), 'INV-20261011-0007');
  });
}
