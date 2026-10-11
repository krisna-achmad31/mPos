import '../../reports/domain/sales_report.dart';
import '../../sales/domain/entities/cart_line.dart';
import '../../sales/domain/entities/invoice.dart';
import '../../sales/domain/entities/sales_order.dart';

/// Barang yang dibeli pelanggan dalam satu periode.
class PurchasedItem {
  const PurchasedItem({required this.name, required this.unit, required this.qty, required this.amount});

  final String name;
  final String unit;
  final int qty;
  final int amount;
}

/// Ringkasan belanja satu pelanggan untuk satu periode.
class CustomerSpending {
  const CustomerSpending({
    required this.total,
    required this.orderCount,
    required this.itemCount,
    required this.pendingCount,
    required this.byCategory,
    required this.itemsByCategory,
    required this.byDay,
  });

  /// Nilai final (invoice) bila sudah diproses, harga katalog bila masih menunggu.
  final int total;
  final int orderCount;
  final int itemCount;

  /// Pesanan yang belum jadi invoice (nilainya masih estimasi).
  final int pendingCount;
  final List<NamedAmount> byCategory;
  final Map<String, List<PurchasedItem>> itemsByCategory;
  final List<TimeBucket> byDay;
}

abstract final class CustomerSpendingBuilder {
  static const otherCategory = 'Lainnya';

  static CustomerSpending build({
    required List<SalesOrder> orders,
    required Map<String, Invoice> invoicesById,
    required Map<String, String> categoryByProduct,
    required DateTime from,
    required DateTime to,
  }) {
    final inRange = orders
        .where((o) => o.status != OrderStatus.cancelled && !o.createdAt.isBefore(from) && o.createdAt.isBefore(to))
        .toList();

    final category = <String, (int amount, int count)>{};
    final items = <String, Map<String, PurchasedItem>>{};
    final perDay = <DateTime, (int, int)>{};
    var total = 0, itemCount = 0, pending = 0;

    for (final order in inRange) {
      final invoice = order.invoiceId == null ? null : invoicesById[order.invoiceId];
      if (invoice != null && invoice.voided) continue;
      if (invoice == null) pending++;

      // Invoice = harga final setelah diskon; diskon nota dibagi proporsional ke baris.
      final List<CartLine> lines = invoice?.lines ?? order.lines;
      final linesNet = lines.fold(0, (s, l) => s + l.net);
      final orderTotal = invoice == null ? linesNet : invoice.totals.total;
      total += orderTotal;

      final day = DateTime(order.createdAt.year, order.createdAt.month, order.createdAt.day);
      final (dAmount, dCount) = perDay[day] ?? (0, 0);
      perDay[day] = (dAmount + orderTotal, dCount + 1);

      final touched = <String>{};
      for (final l in lines) {
        final share = linesNet == 0 ? 0 : (l.net * orderTotal / linesNet).round();
        final cat = (categoryByProduct[l.productId] ?? '').isEmpty ? otherCategory : categoryByProduct[l.productId]!;
        itemCount += l.qty;
        final (a, c) = category[cat] ?? (0, 0);
        category[cat] = (a + share, c + (touched.add(cat) ? 1 : 0));
        final bucket = items.putIfAbsent(cat, () => {});
        final prev = bucket[l.productId];
        bucket[l.productId] = PurchasedItem(
          name: l.name,
          unit: l.unit,
          qty: (prev?.qty ?? 0) + l.qty,
          amount: (prev?.amount ?? 0) + share,
        );
      }
    }

    final byCategory = [for (final e in category.entries) NamedAmount(e.key, e.value.$1, count: e.value.$2)]
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final days = <TimeBucket>[
      for (var d = from; d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1))
        TimeBucket(start: d, amount: perDay[d]?.$1 ?? 0, count: perDay[d]?.$2 ?? 0),
    ];

    return CustomerSpending(
      total: total,
      orderCount: inRange.length,
      itemCount: itemCount,
      pendingCount: pending,
      byCategory: byCategory,
      itemsByCategory: {
        for (final c in byCategory)
          c.name: items[c.name]!.values.toList()..sort((a, b) => b.amount.compareTo(a.amount)),
      },
      byDay: days,
    );
  }
}
