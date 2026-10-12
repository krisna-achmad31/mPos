import '../../../core/error/app_exception.dart';
import '../../pricing/domain/services/pricing_service.dart';
import '../../products/domain/entities/product.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/services/sale_calculator.dart';

/// Edit satu nota demo: jam transaksi dan qty per baris. Murni agar bisa dites.
abstract final class DemoInvoiceEditor {
  /// [qtyByLine] sejajar dengan `invoice.lines`; qty 0 menghapus baris.
  /// [products] dipakai untuk menghitung ulang harga per kemasan (karton/ball/pouch) saat qty berubah.
  static Invoice edit(
    Invoice invoice, {
    required DateTime time,
    required List<int> qtyByLine,
    Map<String, Product> products = const {},
  }) {
    if (qtyByLine.length != invoice.lines.length) throw ArgumentError('qtyByLine tidak sejajar dengan baris nota');
    final day = invoice.createdAt;
    if (time.year != day.year || time.month != day.month || time.day != day.day) {
      throw const AppException('Jam harus di tanggal yang sama dengan nota.');
    }
    final lines = [
      for (var i = 0; i < invoice.lines.length; i++)
        if (qtyByLine[i] > 0) _reprice(invoice.lines[i], qtyByLine[i], products[invoice.lines[i].productId]),
    ];
    if (lines.isEmpty) throw const AppException('Nota harus punya minimal satu barang. Hapus nota bila tidak dipakai.');

    final totals = SaleCalculator.totals(lines);
    final method = invoice.paymentMethod ?? PaymentMethod.cash;
    final given = invoice.paid + invoice.change;
    final payment = switch (method) {
      PaymentMethod.cash => SaleCalculator.pay(
        total: totals.total,
        method: method,
        amount: given >= totals.total ? given : totals.total,
      ),
      PaymentMethod.transfer || PaymentMethod.qris => SaleCalculator.pay(total: totals.total, method: method, amount: totals.total),
      _ => SaleCalculator.pay(
        total: totals.total,
        method: PaymentMethod.credit,
        amount: invoice.paid.clamp(0, totals.total),
      ),
    };

    return Invoice(
      id: invoice.id,
      number: invoice.number,
      source: invoice.source,
      customerName: invoice.customerName,
      lines: lines,
      totals: totals,
      paid: payment.paid,
      change: payment.change,
      paymentMethod: invoice.paymentMethod,
      createdAt: time,
      createdByName: invoice.createdByName,
    );
  }

  static CartLine _reprice(CartLine line, int qty, Product? product) {
    if (product == null || line.priceType == PriceType.manual) {
      return line.copyWith(qty: qty, packs: const []);
    }
    final price = PricingService.priceLine(product, qty);
    return line.copyWith(qty: qty, unitPrice: price.unitPrice, priceType: price.type, packs: price.packs);
  }

  /// Total hari itu setelah [edited] menggantikan nota dengan id yang sama tidak boleh melebihi [target].
  static void ensureWithinTarget(List<Invoice> dayInvoices, Invoice edited, int target) {
    final others = dayInvoices.where((i) => i.id != edited.id).fold(0, (s, i) => s + i.totals.total);
    final total = others + edited.totals.total;
    if (total > target) {
      throw AppException(
        'Total hari ini jadi ${_rp(total)}, melebihi target ${_rp(target)}. '
        'Sisa yang masih bisa dipakai ${_rp(target - others)}.',
      );
    }
  }

  static String _rp(int v) => 'Rp${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
}
