import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/expense_providers.dart';
import '../../../products/product_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';

class ReportMonthViewModel extends Notifier<DateTime> {
  @override
  DateTime build() => startOfMonth(DateTime.now());

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

final reportMonthProvider = NotifierProvider<ReportMonthViewModel, DateTime>(ReportMonthViewModel.new);

final invoicesInMonthProvider = StreamProvider.family<List<Invoice>, DateTime>((ref, month) => ref
    .watch(salesRepositoryProvider)
    .watchInvoices(from: startOfMonth(month), to: startOfNextMonth(month)));

final _costsInMonthProvider = StreamProvider.family<List<InvoiceCost>, DateTime>((ref, month) =>
    ref.watch(salesRepositoryProvider).watchInvoiceCosts(startOfMonth(month), startOfNextMonth(month)));

final _paymentsInMonthProvider = StreamProvider.family<List<PaymentRecord>, DateTime>((ref, month) =>
    ref.watch(salesRepositoryProvider).watchPaymentsBetween(startOfMonth(month), startOfNextMonth(month)));

class ReportSummary extends Equatable {
  const ReportSummary({
    required this.invoiceCount,
    required this.grossSales,
    required this.discounts,
    required this.tax,
    required this.netSales,
    required this.cost,
    required this.expenses,
    required this.expensesByCategory,
    required this.cashByMethod,
    required this.receivables,
    required this.inventoryValue,
  });

  final int invoiceCount;

  /// Harga normal × qty.
  final int grossSales;
  final int discounts;
  final int tax;

  /// Penjualan bersih (tanpa pajak).
  final int netSales;
  final int cost;
  final int expenses;
  final Map<String, int> expensesByCategory;
  final Map<PaymentMethod, int> cashByMethod;
  final int receivables;
  final int inventoryValue;

  int get grossProfit => netSales - cost;

  int get netProfit => grossProfit - expenses;

  @override
  List<Object?> get props => [invoiceCount, grossSales, discounts, tax, netSales, cost, expenses, receivables];
}

/// Laba rugi sederhana: penjualan − diskon − HPP = laba kotor; laba kotor − pengeluaran = laba bersih.
abstract final class ReportCalculator {
  static ReportSummary summarize({
    required List<Invoice> invoices,
    required List<InvoiceCost> costs,
    required List<Expense> expenses,
    required List<PaymentRecord> payments,
    required int inventoryValue,
  }) {
    final valid = invoices.where((i) => !i.voided).toList();
    final validIds = valid.map((i) => i.id).toSet();
    final byCategory = <String, int>{};
    for (final e in expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }
    final byMethod = <PaymentMethod, int>{};
    for (final p in payments) {
      byMethod[p.method] = (byMethod[p.method] ?? 0) + p.amount;
    }
    return ReportSummary(
      invoiceCount: valid.length,
      grossSales: valid.fold(0, (s, i) => s + i.totals.subtotal),
      discounts: valid.fold(0, (s, i) => s + i.totals.totalDiscount),
      tax: valid.fold(0, (s, i) => s + i.totals.tax),
      netSales: valid.fold(0, (s, i) => s + i.totals.total - i.totals.tax),
      cost: costs.where((c) => !c.voided && validIds.contains(c.invoiceId)).fold(0, (s, c) => s + c.totalCost),
      expenses: expenses.fold(0, (s, e) => s + e.amount),
      expensesByCategory: byCategory,
      cashByMethod: byMethod,
      receivables: valid.fold(0, (s, i) => s + i.remaining),
      inventoryValue: inventoryValue,
    );
  }
}

final reportSummaryProvider = Provider<AsyncValue<ReportSummary>>((ref) {
  final month = ref.watch(reportMonthProvider);
  final invoices = ref.watch(invoicesInMonthProvider(month));
  final costs = ref.watch(_costsInMonthProvider(month));
  final expenses = ref.watch(expensesInMonthProvider(month));
  final payments = ref.watch(_paymentsInMonthProvider(month));
  final products = ref.watch(productsProvider);
  final productCosts = ref.watch(productCostsProvider);

  final sources = [invoices, costs, expenses, payments, products, productCosts];
  for (final s in sources) {
    if (s.hasError) return AsyncError(s.error!, s.stackTrace ?? StackTrace.current);
  }
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();

  final hpp = productCosts.value!;
  final inventoryValue = products.value!
      .where((p) => p.trackStock && p.stock > 0)
      .fold(0, (sum, p) => sum + p.stock * (hpp[p.id]?.hpp ?? 0));

  return AsyncData(ReportCalculator.summarize(
    invoices: invoices.value!,
    costs: costs.value!,
    expenses: expenses.value!,
    payments: payments.value!,
    inventoryValue: inventoryValue,
  ));
});
