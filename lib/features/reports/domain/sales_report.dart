import 'package:equatable/equatable.dart';

import '../../products/domain/entities/product.dart';
import '../../sales/domain/entities/invoice.dart';

class NamedAmount extends Equatable {
  const NamedAmount(this.name, this.amount, {this.count = 0});

  final String name;
  final int amount;

  /// Jumlah nota / transaksi di kelompok ini.
  final int count;

  @override
  List<Object?> get props => [name, amount, count];
}

class TimeBucket extends Equatable {
  const TimeBucket({required this.start, required this.amount, required this.count});

  final DateTime start;
  final int amount;
  final int count;

  @override
  List<Object?> get props => [start, amount, count];
}

class ProductStat extends Equatable {
  const ProductStat({
    required this.productId,
    required this.name,
    required this.qty,
    required this.revenue,
    required this.cost,
  });

  final String productId;
  final String name;
  final int qty;

  /// Nilai baris setelah diskon item.
  final int revenue;
  final int cost;

  int get profit => revenue - cost;

  @override
  List<Object?> get props => [productId, qty, revenue, cost];
}

/// Semua angka laporan untuk satu rentang waktu, dari data asli atau data demo.
class SalesReport extends Equatable {
  const SalesReport({
    required this.from,
    required this.to,
    required this.isDemo,
    required this.invoices,
    required this.grossSales,
    required this.discounts,
    required this.tax,
    required this.netSales,
    required this.cost,
    required this.expenses,
    required this.itemsSold,
    required this.receivables,
    required this.byDay,
    required this.byHour,
    required this.products,
    required this.byCategory,
    required this.byPaymentMethod,
    required this.bySource,
    required this.topCustomers,
    required this.expensesByCategory,
    required this.inventoryValue,
    required this.reorder,
  });

  final DateTime from;
  final DateTime to;
  final bool isDemo;

  /// Nota yang dihitung (tidak termasuk batal), urut waktu terbaru dulu.
  final List<Invoice> invoices;
  final int grossSales;
  final int discounts;
  final int tax;
  final int netSales;
  final int cost;
  final int expenses;
  final int itemsSold;
  final int receivables;
  final List<TimeBucket> byDay;

  /// Selalu 24 baris (jam 0–23).
  final List<TimeBucket> byHour;

  /// Diurutkan omzet terbesar.
  final List<ProductStat> products;
  final List<NamedAmount> byCategory;
  final List<NamedAmount> byPaymentMethod;
  final List<NamedAmount> bySource;
  final List<NamedAmount> topCustomers;
  final List<NamedAmount> expensesByCategory;
  final int inventoryValue;
  final List<Product> reorder;

  int get invoiceCount => invoices.length;

  int get averageTicket => invoices.isEmpty ? 0 : (netSales / invoices.length).round();

  int get grossProfit => netSales - cost;

  int get netProfit => grossProfit - expenses;

  double get grossMargin => netSales == 0 ? 0 : grossProfit / netSales;

  TimeBucket? get busiestHour {
    final withSales = byHour.where((b) => b.count > 0).toList();
    if (withSales.isEmpty) return null;
    return withSales.reduce((a, b) => b.amount > a.amount ? b : a);
  }

  @override
  List<Object?> get props => [from, to, isDemo, invoices, netSales, cost, expenses];
}
