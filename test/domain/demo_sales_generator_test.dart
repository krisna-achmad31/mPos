import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/reports/domain/demo_sales_generator.dart';
import 'package:mpos/features/reports/domain/report_builder.dart';

import '../helpers.dart';

void main() {
  final day = DateTime(2026, 10, 11);
  final products = [
    product(id: 'a', name: 'Minyak 1L', price: 20000, stock: 200, wholesalePrice: 18500, wholesaleMinQty: 12),
    product(id: 'b', name: 'Gula 1kg', price: 16000, stock: 150),
    product(id: 'c', name: 'Mie instan', price: 3500, stock: 500),
    product(id: 'd', name: 'Beras 5kg', price: 72000, stock: 40),
    product(id: 'e', name: 'Kopi sachet', price: 1500, stock: 1000),
  ];

  List generate({int target = 1000000, int seed = 1, int open = 8, int close = 21}) =>
      DemoSalesGenerator(seed: seed).generate(
        date: day,
        target: target,
        products: products,
        openHour: open,
        closeHour: close,
      );

  test('total tidak pernah melebihi target dan mendekatinya', () {
    for (var seed = 0; seed < 30; seed++) {
      final invoices = generate(seed: seed);
      final total = invoices.fold<int>(0, (s, i) => s + i.totals.total as int);
      expect(total, lessThanOrEqualTo(1000000), reason: 'seed $seed');
      // Sisa < harga produk termurah, jadi selisihnya sangat kecil.
      expect(total, greaterThan(1000000 - 1500), reason: 'seed $seed');
    }
  });

  test('jam transaksi di dalam jam buka, nomor DEMO berurutan waktu', () {
    final invoices = generate(open: 9, close: 17);
    for (final inv in invoices) {
      expect(inv.createdAt.hour, inInclusiveRange(9, 16));
      expect(inv.number, startsWith('DEMO-20261011-'));
    }
    for (var i = 1; i < invoices.length; i++) {
      expect(invoices[i].createdAt.isBefore(invoices[i - 1].createdAt), isFalse);
    }
  });

  test('stok kecil tidak menghalangi target secara default', () {
    final limited = [product(id: 'x', price: 1600, stock: 3)];
    final invoices = DemoSalesGenerator(seed: 3).generate(date: day, target: 1000000, products: limited);
    final total = invoices.fold<int>(0, (s, i) => s + i.totals.total);
    expect(total, lessThanOrEqualTo(1000000));
    expect(total, greaterThan(1000000 - 1600));
  });

  test('respectStock: qty tidak melebihi stok produk', () {
    final limited = [product(id: 'x', price: 10000, stock: 3), product(id: 'y', price: 5000, stock: 2)];
    final invoices = DemoSalesGenerator(seed: 3)
        .generate(date: day, target: 1000000, products: limited, respectStock: true);
    final sold = <String, int>{};
    for (final inv in invoices) {
      for (final l in inv.lines) {
        sold[l.productId] = (sold[l.productId] ?? 0) + l.qty;
      }
    }
    expect(sold['x'] ?? 0, lessThanOrEqualTo(3));
    expect(sold['y'] ?? 0, lessThanOrEqualTo(2));
  });

  test('seed sama menghasilkan data sama; beberapa nota dengan qty bervariasi', () {
    final a = generate(seed: 7);
    final b = generate(seed: 7);
    expect(a.map((i) => i.number), b.map((i) => i.number));
    expect(a.map((i) => i.totals.total), b.map((i) => i.totals.total));
    expect(a.length, greaterThan(5));
    expect(a.expand((i) => i.lines).map((l) => l.qty).toSet().length, greaterThan(1));
  });

  test('menolak target 0 dan produk kosong', () {
    expect(() => generate(target: 0), throwsA(isA<AppException>()));
    expect(
      () => DemoSalesGenerator(seed: 1).generate(date: day, target: 1000, products: []),
      throwsA(isA<AppException>()),
    );
  });

  test('ReportBuilder menghitung omzet, HPP, dan sebaran jam dari data demo', () {
    final invoices = DemoSalesGenerator(seed: 5).generate(date: day, target: 500000, products: products);
    final report = ReportBuilder.build(
      from: day,
      to: DateTime(2026, 10, 12),
      isDemo: true,
      invoices: invoices,
      hppByProduct: {'a': 15000, 'b': 12000, 'c': 2500, 'd': 60000, 'e': 1000},
      products: products,
      includeStock: false,
    );
    expect(report.invoiceCount, invoices.length);
    expect(report.netSales, invoices.fold<int>(0, (s, i) => s + i.totals.total));
    expect(report.byHour.fold<int>(0, (s, b) => s + b.count), invoices.length);
    expect(report.products.first.revenue, greaterThanOrEqualTo(report.products.last.revenue));
    expect(report.cost, greaterThan(0));
    expect(report.grossProfit, report.netSales - report.cost);
  });
}
