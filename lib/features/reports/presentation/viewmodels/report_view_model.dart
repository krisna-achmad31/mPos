import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../../expenses/expense_providers.dart';
import '../../../products/product_providers.dart';
import '../../../sales/domain/entities/invoice.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../../sales/sales_providers.dart';
import '../../data/demo_report_repository.dart';
import '../../domain/demo_sales_generator.dart';
import '../../domain/report_builder.dart';
import '../../domain/sales_report.dart';

enum ReportMode { real, demo }

enum ReportPeriod { day, month }

class ReportFilter extends Equatable {
  const ReportFilter({required this.mode, required this.period, required this.date});

  final ReportMode mode;
  final ReportPeriod period;

  /// Hari terpilih (period day) atau tanggal mana pun di bulan terpilih.
  final DateTime date;

  DateTime get from => period == ReportPeriod.day ? startOfDay(date) : startOfMonth(date);

  DateTime get to => period == ReportPeriod.day
      ? DateTime(date.year, date.month, date.day + 1)
      : startOfNextMonth(date);

  ReportFilter copyWith({ReportMode? mode, ReportPeriod? period, DateTime? date}) =>
      ReportFilter(mode: mode ?? this.mode, period: period ?? this.period, date: date ?? this.date);

  @override
  List<Object?> get props => [mode, period, date];
}

class ReportFilterViewModel extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => ReportFilter(mode: ReportMode.real, period: ReportPeriod.day, date: startOfDay(DateTime.now()));

  void setMode(ReportMode mode) => state = state.copyWith(mode: mode);

  void setPeriod(ReportPeriod period) => state = state.copyWith(period: period);

  void setDate(DateTime date) => state = state.copyWith(date: startOfDay(date));

  /// Maju / mundur satu hari atau satu bulan sesuai periode.
  void shift(int step) => state = state.copyWith(
        date: state.period == ReportPeriod.day
            ? DateTime(state.date.year, state.date.month, state.date.day + step)
            : DateTime(state.date.year, state.date.month + step),
      );
}

final reportFilterProvider = NotifierProvider<ReportFilterViewModel, ReportFilter>(ReportFilterViewModel.new);

final demoReportRepositoryProvider = Provider((ref) => DemoReportRepository(ref.watch(firestoreProvider)));

final _invoiceCostsProvider = StreamProvider.family<List<InvoiceCost>, DateTime>((ref, month) =>
    ref.watch(salesRepositoryProvider).watchInvoiceCosts(startOfMonth(month), startOfNextMonth(month)));

final _demoInvoicesProvider = StreamProvider.family<List<Invoice>, DateTime>((ref, month) =>
    ref.watch(demoReportRepositoryProvider).watchInvoices(startOfMonth(month), startOfNextMonth(month)));

final demoDayKeysProvider = StreamProvider<Set<String>>((ref) => ref.watch(demoReportRepositoryProvider).watchDemoDayKeys());

/// Laporan sesuai filter: data asli atau data demo (keduanya tidak pernah dicampur).
final salesReportProvider = Provider<AsyncValue<SalesReport>>((ref) {
  final filter = ref.watch(reportFilterProvider);
  final month = startOfMonth(filter.date);
  final products = ref.watch(productsProvider);
  final costs = ref.watch(productCostsProvider);

  if (filter.mode == ReportMode.demo) {
    final demo = ref.watch(_demoInvoicesProvider(month));
    final error = _firstError([products, costs, demo]);
    if (error != null) return error;
    if (!products.hasValue || !costs.hasValue || !demo.hasValue) return const AsyncLoading();
    return AsyncData(ReportBuilder.build(
      from: filter.from,
      to: filter.to,
      isDemo: true,
      invoices: demo.value!,
      hppByProduct: {for (final e in costs.value!.entries) e.key: e.value.hpp},
      products: products.value!,
      includeStock: false,
    ));
  }

  final invoices = ref.watch(invoicesInMonthProvider(month));
  final invoiceCosts = ref.watch(_invoiceCostsProvider(month));
  final expenses = ref.watch(expensesInMonthProvider(month));
  final sources = [products, costs, invoices, invoiceCosts, expenses];
  final error = _firstError(sources);
  if (error != null) return error;
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();

  final from = filter.from;
  final to = filter.to;
  return AsyncData(ReportBuilder.build(
    from: from,
    to: to,
    isDemo: false,
    invoices: invoices.value!,
    hppByProduct: {for (final e in costs.value!.entries) e.key: e.value.hpp},
    costByInvoice: {for (final c in invoiceCosts.value!) c.invoiceId: c.totalCost},
    expenses: expenses.value!.where((e) => !e.date.isBefore(from) && e.date.isBefore(to)).toList(),
    products: products.value!,
  ));
});

AsyncValue<SalesReport>? _firstError(List<AsyncValue<Object?>> values) {
  for (final v in values) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  return null;
}

/// Membuat / menghapus data demo satu hari.
class DemoDataViewModel extends ActionViewModel {
  Future<bool> generate({
    required DateTime date,
    required int target,
    required int openHour,
    required int closeHour,
  }) =>
      run(() async {
        final products = await readReady(activeProductsProvider.future);
        final customers = (await readReady(customersProvider.future)).map((c) => c.displayName).toList();
        final invoices = DemoSalesGenerator(seed: Random().nextInt(1 << 31)).generate(
          date: date,
          target: target,
          products: products,
          customerNames: customers,
          openHour: openHour,
          closeHour: closeHour,
        );
        await ref.read(demoReportRepositoryProvider).saveDay(
              date: date,
              target: target,
              openHour: openHour,
              closeHour: closeHour,
              invoices: invoices,
            );
      });

  Future<bool> deleteDay(DateTime date) => run(() => ref.read(demoReportRepositoryProvider).deleteDay(date));
}

final demoDataViewModelProvider = NotifierProvider<DemoDataViewModel, AsyncValue<void>>(DemoDataViewModel.new);
