import 'package:equatable/equatable.dart';

import '../../pricing/domain/services/pricing_service.dart';
import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/services/sale_calculator.dart';

/// Satu baris rekap transaksi (format Excel "rekap daftar transaksi"): satu produk / kemasan per baris.
class SalesExportRow extends Equatable {
  const SalesExportRow({
    required this.number,
    required this.date,
    required this.cashier,
    required this.sales,
    required this.customer,
    required this.method,
    required this.product,
    required this.unitCost,
    required this.priceType,
    required this.unitPrice,
    required this.discount,
    required this.qty,
    required this.unit,
    required this.amount,
    required this.cashIn,
  });

  final String number;
  final DateTime date;
  final String cashier;
  final String sales;
  final String customer;
  final String method;
  final String product;

  /// Harga modal per [unit] (HPP satuan dasar × isi kemasan).
  final int unitCost;
  final String priceType;
  final int unitPrice;

  /// Diskon item (harga khusus / promo) untuk baris ini.
  final int discount;
  final int qty;
  final String unit;

  /// qty × harga − diskon item.
  final int amount;

  /// [amount] setelah dikurangi bagian diskon nota.
  final int cashIn;

  /// Sama dengan rumus template: DP tidak dihitung profitnya.
  int get profit => method == PaymentMethod.downPayment.label ? 0 : cashIn - unitCost * qty;

  @override
  List<Object?> get props => [number, product, unit, qty, unitPrice, discount, amount, cashIn, unitCost];
}

/// Menyusun baris rekap dari nota. Murni agar bisa dites.
abstract final class SalesExport {
  /// [unitCost]: HPP per satuan dasar untuk produk di nota tertentu.
  static List<SalesExportRow> rows(
    List<Invoice> invoices, {
    required int Function(Invoice invoice, String productId) unitCost,
  }) {
    final sorted = invoices.where((i) => !i.voided).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [for (final inv in sorted) ..._invoiceRows(inv, unitCost)];
  }

  static String methodLabel(Invoice inv) {
    if (inv.isOpenCredit) return PaymentMethod.credit.label;
    final method = inv.paymentMethod;
    if (method != null) return method.label;
    return inv.paymentStatus == PaymentStatus.paid ? 'Lunas' : 'Belum bayar';
  }

  static List<SalesExportRow> _invoiceRows(Invoice inv, int Function(Invoice, String) unitCost) {
    final drafts = <_Draft>[];
    for (final l in inv.lines) {
      final hpp = unitCost(inv, l.productId);
      final parts = <_Draft>[
        for (final p in l.packs)
          _Draft(l.name, 'Harga Jual Kemasan', p.count, _title(p.name), p.price, hpp * p.contents),
        if (l.looseQty > 0 || l.packs.isEmpty)
          _Draft(l.name, _priceType(l.priceType), l.looseQty, l.unit, l.unitPrice, hpp),
      ];
      // Diskon item dicatat di baris terakhir produk itu (sama seperti nota PDF).
      parts.last.discount = l.discountAmount;
      drafts.addAll(parts);
    }

    // Diskon nota dibagi proporsional ke tiap baris; sisa pembulatan ke baris terakhir.
    final orderDiscount = inv.totals.orderDiscount;
    final base = drafts.fold(0, (s, d) => s + d.amount);
    var allocated = 0;
    for (var i = 0; i < drafts.length; i++) {
      final share = i == drafts.length - 1
          ? orderDiscount - allocated
          : (base == 0 ? 0 : (orderDiscount * drafts[i].amount / base).round());
      allocated += share;
      drafts[i].orderDiscount = share;
    }

    final method = methodLabel(inv);
    return [
      for (final d in drafts)
        SalesExportRow(
          number: inv.number,
          date: inv.createdAt,
          cashier: inv.createdByName,
          sales: inv.salesName,
          customer: inv.customerName.isEmpty ? 'UMUM' : inv.customerName,
          method: method,
          product: d.product.toUpperCase(),
          unitCost: d.unitCost,
          priceType: d.priceType,
          unitPrice: d.unitPrice,
          discount: d.discount,
          qty: d.qty,
          unit: d.unit,
          amount: d.amount,
          cashIn: d.amount - d.orderDiscount,
        ),
    ];
  }

  static String _priceType(PriceType t) => switch (t) {
        PriceType.wholesale => 'Harga Jual Grosir',
        PriceType.manual => 'Harga Jual Manual',
        PriceType.retail || PriceType.pack => 'Harga Jual Satuan',
      };

  static String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Draft {
  _Draft(this.product, this.priceType, this.qty, this.unit, this.unitPrice, this.unitCost);

  final String product;
  final String priceType;
  final int qty;
  final String unit;
  final int unitPrice;
  final int unitCost;
  int discount = 0;
  int orderDiscount = 0;

  int get amount => qty * unitPrice - discount;
}
