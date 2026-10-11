import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../products/product_providers.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../../sales/sales_providers.dart';
import '../../domain/customer_spending.dart';

/// Bulan yang sedang dilihat di halaman Belanja Saya.
final spendingMonthProvider = NotifierProvider<ReportMonthViewModel, DateTime>(ReportMonthViewModel.new);

/// Ringkasan belanja pelanggan yang login untuk bulan terpilih.
final customerSpendingProvider = Provider<AsyncValue<CustomerSpending>>((ref) {
  final month = ref.watch(spendingMonthProvider);
  final orders = ref.watch(ordersProvider);
  final invoices = ref.watch(myInvoicesProvider);
  final products = ref.watch(productsProvider);

  for (final v in [orders, invoices, products]) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  if (!orders.hasValue || !invoices.hasValue || !products.hasValue) return const AsyncLoading();

  return AsyncData(CustomerSpendingBuilder.build(
    orders: orders.value!,
    invoicesById: {for (final i in invoices.value!) i.id: i},
    categoryByProduct: {for (final p in products.value!) p.id: p.category},
    from: startOfMonth(month),
    to: startOfNextMonth(month),
  ));
});
