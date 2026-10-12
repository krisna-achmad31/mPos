import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/reports/domain/cafe_demo_catalog.dart';
import 'package:mpos/features/reports/domain/demo_sales_generator.dart';
import 'package:mpos/features/reports/domain/report_builder.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';

void main() {
  final day = DateTime(2026, 10, 12);

  List<Invoice> generate(int seed) => DemoSalesGenerator(seed: seed).generate(
        date: day,
        target: 3000000,
        products: CafeDemoCatalog.products,
        customerNames: const ['Kopi Senja Sore'],
        openHour: 7,
        closeHour: 22,
        profile: BuyerProfile.cafe,
      );

  test('data demo kopi: pembeli umum di kasir, bayar tunai / QRIS / transfer, total <= target', () {
    for (var seed = 0; seed < 20; seed++) {
      final invoices = generate(seed);
      expect(invoices.fold(0, (s, i) => s + i.totals.total), lessThanOrEqualTo(3000000));
      for (final inv in invoices) {
        expect(inv.customerName, 'UMUM');
        expect(inv.source, InvoiceSource.pos);
        expect(inv.paymentMethod, isIn([PaymentMethod.cash, PaymentMethod.qris, PaymentMethod.transfer]));
        expect(inv.createdAt.hour, inInclusiveRange(7, 21));
      }
    }
  });

  test('keranjang kecil: rata-rata di bawah 3 porsi per struk', () {
    final invoices = [for (var seed = 0; seed < 10; seed++) ...generate(seed)];
    final cups = invoices.fold(0, (s, i) => s + i.lines.fold(0, (a, l) => a + l.qty));
    expect(cups / invoices.length, lessThan(3));
  });

  test('laporan demo kopi memakai HPP menu contoh sehingga laba terhitung', () {
    final report = ReportBuilder.build(
      from: day,
      to: DateTime(2026, 10, 13),
      isDemo: true,
      invoices: generate(3),
      hppByProduct: CafeDemoCatalog.hpp,
      products: CafeDemoCatalog.products,
      includeStock: false,
    );
    expect(report.cost, greaterThan(0));
    expect(report.grossMargin, inInclusiveRange(0.5, 0.8));
    expect(report.byCategory.map((c) => c.name), containsAll(['Kopi']));
  });
}
