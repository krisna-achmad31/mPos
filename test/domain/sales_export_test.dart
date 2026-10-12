import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/reports/data/sales_xlsx.dart';
import 'package:mpos/features/reports/domain/sales_export.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';

CartLine line(String name, int qty, int price,
        {String unit = 'Pcs', PriceType type = PriceType.retail, List<PackUsage> packs = const [], int discount = 0}) =>
    CartLine(
      productId: name,
      name: name,
      unit: unit,
      qty: qty,
      unitPrice: price,
      priceType: type,
      trackStock: true,
      packs: packs,
      discountAmount: discount,
    );

Invoice invoice(String number, List<CartLine> lines,
        {PaymentMethod? method = PaymentMethod.cash, int orderDiscount = 0, bool voided = false, DateTime? dueDate}) {
  final totals = SaleCalculator.totals(lines, orderDiscount: OrderDiscount.amount(orderDiscount.toDouble()));
  return Invoice(
    id: number,
    number: number,
    source: InvoiceSource.pos,
    customerName: '',
    lines: lines,
    totals: totals,
    paid: method == PaymentMethod.cash ? totals.total : 0,
    change: 0,
    paymentMethod: method,
    createdAt: DateTime(2026, 10, 11, 13, 19),
    createdByName: 'GOJO',
    voided: voided,
    dueDate: dueDate,
  );
}

void main() {
  final hpp = {'SEDOTAN': 15000, 'HERRING LYCHEE': 15000, 'SIRUP': 80000};
  final invoices = [
    invoice('10000001', [line('Sedotan', 60, 17500, unit: 'Ball', type: PriceType.wholesale)]),
    invoice('10000002', [
      line('Herring Lychee', 103, 20000,
          type: PriceType.pack, packs: const [PackUsage(name: 'karton', count: 5, contents: 20, price: 385000)]),
      line('Sirup', 2, 89000, discount: 4000),
    ], orderDiscount: 10000),
    invoice('10000003', [line('Sirup', 1, 89000)], voided: true),
    invoice('10000004', [line('Sirup', 1, 89000)], method: null, dueDate: DateTime(2026, 10, 20)),
  ];
  final rows = SalesExport.rows(invoices, unitCost: (inv, id) => hpp[id.toUpperCase()] ?? 0);

  test('satu baris per produk / kemasan, nota batal dilewati', () {
    expect(rows.map((r) => '${r.number} ${r.product} ${r.qty} ${r.unit}'), [
      '10000001 SEDOTAN 60 Ball',
      '10000002 HERRING LYCHEE 5 Karton',
      '10000002 HERRING LYCHEE 3 Pcs',
      '10000002 SIRUP 2 Pcs',
      '10000004 SIRUP 1 Pcs',
    ]);
    expect(rows.first.customer, 'UMUM');
    expect(rows.first.priceType, 'Harga Jual Grosir');
    expect(rows[1].priceType, 'Harga Jual Kemasan');
    expect(rows.last.method, 'Tempo');
  });

  test('modal kemasan = HPP × isi; profit = kas masuk − modal × qty', () {
    final sedotan = rows.first;
    expect(sedotan.amount, 1050000);
    expect(sedotan.profit, 1050000 - 15000 * 60); // 150.000 seperti contoh template
    expect(rows[1].unitCost, 15000 * 20);
  });

  test('diskon item di baris produknya, diskon nota dibagi proporsional', () {
    final inv2 = rows.where((r) => r.number == '10000002').toList();
    expect(inv2.last.discount, 4000);
    expect(inv2.last.amount, 2 * 89000 - 4000);
    final cashIn = inv2.fold(0, (s, r) => s + r.cashIn);
    expect(cashIn, invoices[1].totals.total); // total nota setelah semua diskon
  });

  test('file xlsx valid berisi header dan rumus profit', () {
    final bytes = SalesXlsx.build(rows);
    final zip = ZipDecoder().decodeBytes(bytes);
    final sheet = String.fromCharCodes(zip.findFile('xl/worksheets/sheet1.xml')!.content);
    expect(sheet, contains('No.\nTransaksi'));
    expect(sheet, contains('<f>IF(F2="DP",0,O2-(H2*L2))</f><v>150000</v>'));
    expect(SalesXlsx.excelDate(DateTime(2026, 9, 11, 13, 19)), closeTo(46276.555, 0.001));
    final out = Platform.environment['XLSX_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });
}
