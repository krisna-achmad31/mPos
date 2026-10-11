import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/reports/domain/demo_catalog.dart';
import 'package:mpos/features/reports/domain/demo_invoice_editor.dart';
import 'package:mpos/features/reports/domain/demo_sales_generator.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';

void main() {
  final day = DateTime(2026, 10, 12);

  List<Invoice> generateCafe({int target = 5000000, int seed = 4}) => DemoSalesGenerator(seed: seed).generate(
        date: day,
        target: target,
        products: DemoCatalog.products,
        customerNames: DemoCatalog.customers,
        profile: BuyerProfile.wholesale,
      );

  test('katalog demo cafe: id berawalan demo- dan setiap produk punya HPP < harga', () {
    for (final p in DemoCatalog.products) {
      expect(p.id, startsWith('demo-'));
      expect(DemoCatalog.hpp[p.id], lessThan(p.sellPrice));
    }
  });

  test('profil grosir: total <= target, mayoritas pelanggan cafe, keranjang lebih besar', () {
    final invoices = generateCafe();
    final total = invoices.fold<int>(0, (s, i) => s + i.totals.total);
    expect(total, lessThanOrEqualTo(5000000));
    final many = [for (var seed = 0; seed < 10; seed++) ...generateCafe(seed: seed)];
    final named = many.where((i) => i.customerName != 'UMUM').length;
    expect(named / many.length, greaterThan(0.75));
    final avgLines = invoices.fold<int>(0, (s, i) => s + i.lines.length) / invoices.length;
    expect(avgLines, greaterThan(2));
  });

  group('DemoInvoiceEditor', () {
    final invoice = generateCafe(seed: 9).first;

    test('mengubah jam dan qty lalu menghitung ulang total', () {
      final qty = [for (final l in invoice.lines) l.qty + 1];
      final edited = DemoInvoiceEditor.edit(
        invoice,
        time: DateTime(2026, 10, 12, 14, 30),
        qtyByLine: qty,
      );
      expect(edited.createdAt.hour, 14);
      expect(edited.totals.total, SaleCalculator.totals(edited.lines).total);
      expect(edited.totals.total, greaterThan(invoice.totals.total));
      expect(edited.number, invoice.number);
    });

    test('qty 0 menghapus baris, semua 0 ditolak', () {
      final qty = [for (var i = 0; i < invoice.lines.length; i++) i == 0 ? 0 : invoice.lines[i].qty];
      if (invoice.lines.length > 1) {
        final edited = DemoInvoiceEditor.edit(invoice, time: invoice.createdAt, qtyByLine: qty);
        expect(edited.lines.length, invoice.lines.length - 1);
      }
      expect(
        () => DemoInvoiceEditor.edit(invoice, time: invoice.createdAt, qtyByLine: [for (final _ in invoice.lines) 0]),
        throwsA(isA<AppException>()),
      );
    });

    test('jam harus di tanggal yang sama', () {
      expect(
        () => DemoInvoiceEditor.edit(invoice,
            time: DateTime(2026, 10, 13, 9), qtyByLine: [for (final l in invoice.lines) l.qty]),
        throwsA(isA<AppException>()),
      );
    });

    test('total hari itu tidak boleh melebihi target', () {
      final all = generateCafe(target: 3000000, seed: 2);
      final first = all.first;
      final bigger = DemoInvoiceEditor.edit(first,
          time: first.createdAt, qtyByLine: [for (final l in first.lines) l.qty * 50]);
      expect(() => DemoInvoiceEditor.ensureWithinTarget(all, bigger, 3000000), throwsA(isA<AppException>()));
      final same = DemoInvoiceEditor.edit(first, time: first.createdAt, qtyByLine: [for (final l in first.lines) l.qty]);
      DemoInvoiceEditor.ensureWithinTarget(all, same, 3000000);
    });
  });
}
