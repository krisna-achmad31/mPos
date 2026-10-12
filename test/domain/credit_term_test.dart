import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';
import 'package:mpos/features/sales/presentation/views/invoices_view.dart';

Invoice invoice({
  int paid = 0,
  PaymentMethod? method,
  DateTime? dueDate,
  bool voided = false,
}) =>
    Invoice(
      id: 'i',
      number: 'INV-1',
      source: InvoiceSource.online,
      customerName: 'Toko',
      lines: const [],
      totals: const SaleTotals(subtotal: 100, itemDiscount: 0, orderDiscount: 0, taxPercent: 0, tax: 0, total: 100),
      paid: paid,
      change: 0,
      paymentMethod: method,
      createdAt: DateTime(2026, 10, 1),
      dueDate: dueDate,
      voided: voided,
    );

void main() {
  test('QRIS lunas langsung seperti transfer', () {
    final r = SaleCalculator.pay(total: 100, method: PaymentMethod.qris, amount: 0);
    expect(r.paid, 100);
    expect(r.remaining, 0);
  });

  test('tempo terbuka sampai lunas', () {
    expect(invoice(dueDate: DateTime(2026, 10, 20)).isOpenCredit, isTrue);
    expect(invoice(method: PaymentMethod.credit).isOpenCredit, isTrue); // tempo dari kasir tanpa tanggal
    expect(invoice(paid: 100, method: PaymentMethod.transfer, dueDate: DateTime(2026, 10, 20)).isOpenCredit, isFalse);
    expect(invoice(voided: true, dueDate: DateTime(2026, 10, 20)).isOpenCredit, isFalse);
    expect(invoice().isOpenCredit, isFalse); // pesanan online belum bayar, bukan tempo
  });

  test('lewat jatuh tempo dihitung per hari', () {
    final inv = invoice(dueDate: DateTime(2026, 10, 20));
    expect(inv.isOverdue(DateTime(2026, 10, 20, 23, 59)), isFalse);
    expect(inv.isOverdue(DateTime(2026, 10, 21)), isTrue);
  });

  test('filter riwayat nota', () {
    final tempo = invoice(dueDate: DateTime(2026, 10, 20));
    final settled = invoice(paid: 100, method: PaymentMethod.qris, dueDate: DateTime(2026, 10, 20));
    final cash = invoice(paid: 100, method: PaymentMethod.cash);
    expect(InvoiceFilter.credit.matches(tempo), isTrue);
    expect(InvoiceFilter.credit.matches(settled), isFalse);
    expect(InvoiceFilter.qris.matches(settled), isTrue); // tempo yang sudah dibayar pindah ke QRIS
    expect(InvoiceFilter.cash.matches(cash), isTrue);
    expect(InvoiceFilter.transfer.matches(cash), isFalse);
    expect(InvoiceFilter.unpaid.matches(tempo), isTrue);
  });
}
