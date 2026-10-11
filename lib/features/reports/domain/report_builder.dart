import '../../expenses/domain/expense.dart';
import '../../products/domain/entities/product.dart';
import '../../sales/domain/entities/invoice.dart';
import 'sales_report.dart';

/// Menyusun [SalesReport] dari nota. Murni (tanpa Firebase) agar bisa dites.
abstract final class ReportBuilder {
  static SalesReport build({
    required DateTime from,
    required DateTime to,
    required bool isDemo,
    required List<Invoice> invoices,
    required Map<String, int> hppByProduct,
    Map<String, int> costByInvoice = const {},
    List<Expense> expenses = const [],
    List<Product> products = const [],
    bool includeStock = true,
  }) {
    final valid = invoices.where((i) => !i.voided && !i.createdAt.isBefore(from) && i.createdAt.isBefore(to)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final productById = {for (final p in products) p.id: p};

    int lineCost(String productId, int qty) => (hppByProduct[productId] ?? 0) * qty;
    int invoiceCost(Invoice i) => costByInvoice[i.id] ?? i.lines.fold(0, (s, l) => s + lineCost(l.productId, l.qty));

    final productStats = <String, ProductStat>{};
    final category = <String, (int, int)>{};
    final method = <String, (int, int)>{};
    final source = <String, (int, int)>{};
    final customers = <String, (int, int)>{};
    var itemsSold = 0;

    void add(Map<String, (int, int)> map, String key, int amount) {
      final (a, c) = map[key] ?? (0, 0);
      map[key] = (a + amount, c + 1);
    }

    for (final inv in valid) {
      final net = inv.totals.total - inv.totals.tax;
      add(method, inv.paymentMethod?.label ?? 'Pesanan online', net);
      add(source, inv.source == InvoiceSource.pos ? 'Kasir langsung' : 'Pesanan online', net);
      add(customers, inv.customerName.isEmpty ? 'UMUM' : inv.customerName, net);
      for (final l in inv.lines) {
        itemsSold += l.qty;
        final prev = productStats[l.productId];
        productStats[l.productId] = ProductStat(
          productId: l.productId,
          name: l.name,
          qty: (prev?.qty ?? 0) + l.qty,
          revenue: (prev?.revenue ?? 0) + l.net,
          cost: (prev?.cost ?? 0) + lineCost(l.productId, l.qty),
        );
        final cat = productById[l.productId]?.category ?? '';
        add(category, cat.isEmpty ? 'Tanpa kategori' : cat, l.net);
      }
    }

    // Per hari (rentang bulanan) dan per jam.
    final days = <TimeBucket>[];
    for (var d = from; d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) {
      final next = DateTime(d.year, d.month, d.day + 1);
      final inDay = valid.where((i) => !i.createdAt.isBefore(d) && i.createdAt.isBefore(next));
      days.add(
        TimeBucket(start: d, amount: inDay.fold(0, (s, i) => s + i.totals.total - i.totals.tax), count: inDay.length),
      );
    }
    final hours = List.generate(24, (h) {
      final inHour = valid.where((i) => i.createdAt.hour == h);
      return TimeBucket(
        start: DateTime(from.year, from.month, from.day, h),
        amount: inHour.fold(0, (s, i) => s + i.totals.total - i.totals.tax),
        count: inHour.length,
      );
    });

    final expenseCategory = <String, (int, int)>{};
    for (final e in expenses) {
      add(expenseCategory, e.category, e.amount);
    }

    List<NamedAmount> sorted(Map<String, (int, int)> map, {int? limit}) {
      final list = [for (final e in map.entries) NamedAmount(e.key, e.value.$1, count: e.value.$2)]
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return limit == null ? list : list.take(limit).toList();
    }

    final stats = productStats.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return SalesReport(
      from: from,
      to: to,
      isDemo: isDemo,
      invoices: valid,
      grossSales: valid.fold(0, (s, i) => s + i.totals.subtotal),
      discounts: valid.fold(0, (s, i) => s + i.totals.totalDiscount),
      tax: valid.fold(0, (s, i) => s + i.totals.tax),
      netSales: valid.fold(0, (s, i) => s + i.totals.total - i.totals.tax),
      cost: valid.fold(0, (s, i) => s + invoiceCost(i)),
      expenses: expenses.fold(0, (s, e) => s + e.amount),
      itemsSold: itemsSold,
      receivables: valid.fold(0, (s, i) => s + i.remaining),
      byDay: days,
      byHour: hours,
      products: stats,
      byCategory: sorted(category),
      byPaymentMethod: sorted(method),
      bySource: sorted(source),
      topCustomers: sorted(customers, limit: 10),
      expensesByCategory: sorted(expenseCategory),
      inventoryValue: includeStock
          ? products
                .where((p) => p.trackStock && p.stock > 0)
                .fold(0, (s, p) => s + p.stock * (hppByProduct[p.id] ?? 0))
          : 0,
      reorder: includeStock ? products.where((p) => p.active && p.needsReorder).toList() : const [],
    );
  }
}
