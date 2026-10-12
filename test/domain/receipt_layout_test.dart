import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/cafe/printing/escpos.dart';
import 'package:mpos/features/cafe/printing/receipt_layout.dart';
import 'package:mpos/features/cafe/printing/receipt_printer.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';

void main() {
  const lines = [
    CartLine(
      productId: 'latte',
      name: 'Caramel Macchiato Extra Shot Oat Milk',
      unit: 'porsi',
      qty: 2,
      unitPrice: 30000,
      priceType: PriceType.retail,
      trackStock: false,
    ),
    CartLine(productId: 'air', name: 'Air Mineral', unit: 'porsi', qty: 1, unitPrice: 6000, priceType: PriceType.retail, trackStock: false),
  ];
  final totals = SaleCalculator.totals(lines, taxPercent: 10);
  final invoice = Invoice(
    id: 'i1',
    number: 'K-20261012-0001',
    source: InvoiceSource.pos,
    customerName: 'Budi',
    lines: lines,
    totals: totals,
    paid: totals.total,
    change: 100000 - totals.total,
    paymentMethod: PaymentMethod.cash,
    createdAt: DateTime(2026, 10, 12, 14, 3),
    createdByName: 'Sari',
  );
  const store = StoreSettings(storeName: 'Kopi Senja Sore', address: 'Jl. Melati No. 5', receiptFooter: 'Terima kasih\nSampai jumpa');

  for (final width in [32, 48]) {
    test('tidak ada baris melebihi $width karakter', () {
      final result = ReceiptLayout.build(invoice: invoice, store: store, width: width);
      for (final l in result) {
        expect(l.text.length, lessThanOrEqualTo(l.large ? width ~/ 2 : width), reason: l.text);
      }
    });
  }

  test('isi struk: kop, item, pajak, total, tunai & kembalian, footer', () {
    final text = ReceiptLayout.build(invoice: invoice, store: store, width: 32).map((l) => l.text).join('\n');
    expect(text, contains('Kopi Senja Sore'));
    expect(text, contains('K-20261012-0001'));
    expect(text, contains('Sari'));
    expect(text, contains('Budi'));
    expect(text, contains('  2 x 30.000'));
    expect(text, contains('Pajak 10%'));
    expect(text, contains('Tunai'));
    expect(text, contains('100.000'));
    expect(text, contains('Kembali'));
    expect(text, contains('Sampai jumpa'));
    expect(text, isNot(contains('CETAK ULANG')));
  });

  test('cetak ulang diberi tanda', () {
    final text = ReceiptLayout.build(invoice: invoice, store: store, width: 32, reprint: true).map((l) => l.text);
    expect(text, contains('** CETAK ULANG **'));
  });

  test('kolom kiri-kanan rata dan memotong teks kiri yang panjang', () {
    expect(ReceiptLayout.columns('Total', '9.000', 16), 'Total      9.000');
    expect(ReceiptLayout.columns('Nama yang sangat panjang', '9.000', 16), 'Nama yang  9.000');
  });

  test('wrap memecah per kata dan memotong kata yang terlalu panjang', () {
    expect(ReceiptLayout.wrap('Kopi susu gula aren', 10), ['Kopi susu', 'gula aren']);
    expect(ReceiptLayout.wrap('ABCDEFGHIJKL', 5), ['ABCDE', 'FGHIJ', 'KL']);
  });

  group('ESC/POS', () {
    test('diawali reset, diakhiri potong kertas', () {
      final bytes = EscPos.encode(const [ReceiptLine('Halo')]);
      expect(bytes.take(2), [0x1B, 0x40]);
      expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    });

    test('perataan tengah, tebal, dan huruf besar', () {
      final bytes = EscPos.encode(const [ReceiptLine('A', align: ReceiptAlign.center, bold: true, large: true)], cut: false);
      expect(bytes.sublist(2, 11), [0x1B, 0x61, 1, 0x1B, 0x45, 1, 0x1D, 0x21, 0x11]);
    });

    test('karakter non-ASCII diganti agar printer tidak mencetak karakter aneh', () {
      expect(EscPos.text('Rp 1.000 – café ☕'), 'Rp 1.000 - cafe ?'.codeUnits);
    });
  });

  test('PDF gulungan 58 / 80 mm terbentuk dari baris struk yang sama', () async {
    for (final paper in [58, 80]) {
      final layout = ReceiptLayout.build(invoice: invoice, store: store, width: paper == 80 ? 48 : 32);
      final pdf = await ReceiptPrinter.buildPdf(layout, paper);
      expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    }
  });

  test('semua baris struk ASCII (aman untuk Courier di PDF)', () {
    final text = ReceiptLayout.build(invoice: invoice, store: store, width: 32).map((l) => l.text).join();
    expect(text.runes.every((r) => r < 0x80), isTrue);
  });
}
