import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mpos/features/auth/domain/entities/app_user.dart';
import 'package:mpos/features/auth/domain/entities/user_role.dart';
import 'package:mpos/features/pricing/domain/services/pricing_service.dart';
import 'package:mpos/features/sales/domain/entities/cart_line.dart';
import 'package:mpos/features/sales/domain/entities/invoice.dart';
import 'package:mpos/features/sales/domain/services/sale_calculator.dart';
import 'package:mpos/features/sales/presentation/invoice_pdf.dart';
import 'package:mpos/features/settings/domain/store_settings.dart';

CartLine line(String name, String unit, int qty, int price, {List<PackUsage> packs = const [], int discount = 0}) =>
    CartLine(
      productId: name,
      name: name,
      unit: unit,
      qty: qty,
      unitPrice: price,
      priceType: PriceType.retail,
      trackStock: true,
      packs: packs,
      discountAmount: discount,
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final lines = [
    line('Powder Masterista Lychee Tea 1kg', 'Pcs', 5, 75000),
    line('Herring Lychee', 'Pcs', 103, 20000, packs: const [PackUsage(name: 'Karton', count: 5, contents: 20, price: 385000)]),
    line('Prof Bar Concentrate Syrup Strawberry 1,2 L', 'Pcs', 2, 89000, discount: 4000),
  ];
  final invoice = Invoice(
    id: 'i1',
    number: '10000049',
    source: InvoiceSource.online,
    customerId: 'c1',
    customerName: 'TROPIS',
    lines: lines,
    totals: SaleCalculator.totals(lines),
    paid: 0,
    change: 0,
    paymentMethod: PaymentMethod.cash,
    createdAt: DateTime(2026, 10, 11),
  );
  const settings = StoreSettings(
    address: 'Jl. Gunungsari No 7A, Jagalan, Kota Kediri 80351',
    phone: '082131968145',
    bankInfo: 'Bank : BCA\nNo. Rekening : 0334297779\nAtas Nama : Fajar Sang Sinatria',
  );

  test('invoice PDF tanpa logo (hanya nama distributor)', () async {
    final bytes = await buildInvoicePdf(InvoicePrintData(
      invoice: invoice,
      distributorName: 'Mitra Groceries',
      settings: settings,
      customer: const AppUser(uid: 'c1', name: 'Tropis', email: 'tropis@mail.com', role: UserRole.customer, phone: '0812'),
    ));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['INVOICE_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('invoice PDF dengan logo PNG', () async {
    final logoPath = Platform.environment['INVOICE_LOGO'];
    if (logoPath == null) return;
    final bytes = await buildInvoicePdf(InvoicePrintData(
      invoice: invoice,
      distributorName: 'Mitra Groceries',
      settings: settings,
      logoPng: File(logoPath).readAsBytesSync(),
    ));
    final out = Platform.environment['INVOICE_PDF_OUT'];
    if (out != null) File(out.replaceAll('.pdf', '_logo.pdf')).writeAsBytesSync(bytes);
  });

  test('nama file PDF = nomor invoice', () {
    expect(invoicePdfFileName(invoice), '10000049.pdf');
  });
}
