import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../../auth/auth_providers.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/expense_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../../sales/domain/entities/invoice.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../../sales/sales_providers.dart';
import '../../data/demo_report_repository.dart';
import '../../data/sales_xlsx.dart';
import '../../domain/cafe_demo_catalog.dart';
import '../../domain/demo_catalog.dart';
import '../../domain/demo_invoice_editor.dart';
import '../../domain/demo_sales_generator.dart';
import '../../domain/report_builder.dart';
import '../../domain/sales_export.dart';
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

  DateTime get to =>
      period == ReportPeriod.day ? DateTime(date.year, date.month, date.day + 1) : startOfNextMonth(date);

  ReportFilter copyWith({ReportMode? mode, ReportPeriod? period, DateTime? date}) =>
      ReportFilter(mode: mode ?? this.mode, period: period ?? this.period, date: date ?? this.date);

  @override
  List<Object?> get props => [mode, period, date];
}

class ReportFilterViewModel extends Notifier<ReportFilter> {
  @override
  ReportFilter build() =>
      ReportFilter(mode: ReportMode.real, period: ReportPeriod.day, date: startOfDay(DateTime.now()));

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

final demoReportRepositoryProvider = Provider((ref) => DemoReportRepository(ref.watch(tenantStoreProvider)));

/// Katalog contoh untuk data demo: bahan cafe (distributor) atau menu kopi (POS kopi).
typedef DemoCatalogSet = ({List<Product> products, Map<String, int> hpp, List<String> customers, BuyerProfile profile});

final demoCatalogProvider = Provider<DemoCatalogSet>(
  (ref) => ref.watch(isCafeWorkspaceProvider)
      ? (products: CafeDemoCatalog.products, hpp: CafeDemoCatalog.hpp, customers: const [], profile: BuyerProfile.cafe)
      : (products: DemoCatalog.products, hpp: DemoCatalog.hpp, customers: DemoCatalog.customers, profile: BuyerProfile.wholesale),
);

final _invoiceCostsProvider = StreamProvider.family<List<InvoiceCost>, DateTime>(
  (ref, month) => ref.watch(salesRepositoryProvider).watchInvoiceCosts(startOfMonth(month), startOfNextMonth(month)),
);

final _demoInvoicesProvider = StreamProvider.family<List<Invoice>, DateTime>(
  (ref, month) => ref.watch(demoReportRepositoryProvider).watchInvoices(startOfMonth(month), startOfNextMonth(month)),
);

/// Hari-hari yang punya data demo, dengan target & sumber produknya.
final demoDaysProvider = StreamProvider<Map<String, DemoDay>>(
  (ref) => ref.watch(demoReportRepositoryProvider).watchDays(),
);

/// Laporan sesuai filter: data asli atau data demo (keduanya tidak pernah dicampur).
final salesReportProvider = Provider<AsyncValue<SalesReport>>((ref) {
  final filter = ref.watch(reportFilterProvider);
  final month = startOfMonth(filter.date);
  final products = ref.watch(productsProvider);
  final costs = ref.watch(productCostsProvider);

  // Pengeluaran asli dihitung di kedua mode: demo dipakai untuk uji coba laba bersih sebelum live.
  final expenses = ref.watch(expensesInMonthProvider(month));
  List<Expense> expensesInRange() => filter.period == ReportPeriod.month
      ? expenses.value!
      : ReportBuilder.dailyShareOfExpenses(expenses.value!, month);

  if (filter.mode == ReportMode.demo) {
    final catalog = ref.watch(demoCatalogProvider);
    final demo = ref.watch(_demoInvoicesProvider(month));
    final error = _firstError([products, costs, demo, expenses]);
    if (error != null) return error;
    if (!products.hasValue || !costs.hasValue || !demo.hasValue || !expenses.hasValue) return const AsyncLoading();
    return AsyncData(
      ReportBuilder.build(
        from: filter.from,
        to: filter.to,
        isDemo: true,
        invoices: demo.value!,
        hppByProduct: {for (final e in costs.value!.entries) e.key: e.value.hpp, ...catalog.hpp},
        products: [...products.value!, ...catalog.products],
        expenses: expensesInRange(),
        includeStock: false,
      ),
    );
  }

  final invoices = ref.watch(invoicesInMonthProvider(month));
  final invoiceCosts = ref.watch(_invoiceCostsProvider(month));
  final sources = [products, costs, invoices, invoiceCosts, expenses];
  final error = _firstError(sources);
  if (error != null) return error;
  if (sources.any((s) => !s.hasValue)) return const AsyncLoading();

  final from = filter.from;
  final to = filter.to;
  return AsyncData(
    ReportBuilder.build(
      from: from,
      to: to,
      isDemo: false,
      invoices: invoices.value!,
      hppByProduct: {for (final e in costs.value!.entries) e.key: e.value.hpp},
      costByInvoice: {for (final c in invoiceCosts.value!) c.invoiceId: c.totalCost},
      expenses: expensesInRange(),
      products: products.value!,
    ),
  );
});

AsyncValue<SalesReport>? _firstError(List<AsyncValue<Object?>> values) {
  for (final v in values) {
    if (v.hasError) return AsyncError(v.error!, v.stackTrace ?? StackTrace.current);
  }
  return null;
}

/// Membuat, mengedit, dan menghapus data demo.
class DemoDataViewModel extends ActionViewModel {
  /// [useDemoCatalog] true = katalog contoh distributor cafe; false = produk asli.
  Future<bool> generate({
    required DateTime date,
    required int target,
    required int openHour,
    required int closeHour,
    required bool useDemoCatalog,
  }) => run(() async {
    final catalog = ref.read(demoCatalogProvider);
    final cafe = catalog.profile == BuyerProfile.cafe;
    // Bundling dilewati: data demo tidak memotong stok isinya.
    final products = useDemoCatalog
        ? catalog.products
        : (await readReady(activeProductsProvider.future)).where((p) => !p.isBundle).toList();
    final customers = useDemoCatalog || cafe
        ? catalog.customers
        : (await readReady(customersProvider.future)).map((c) => c.displayName).toList();
    final invoices = DemoSalesGenerator(seed: Random().nextInt(1 << 31)).generate(
      date: date,
      target: target,
      products: products,
      customerNames: customers,
      openHour: openHour,
      closeHour: closeHour,
      profile: cafe ? BuyerProfile.cafe : (useDemoCatalog ? BuyerProfile.wholesale : BuyerProfile.retail),
    );
    await ref
        .read(demoReportRepositoryProvider)
        .saveDay(
          date: date,
          target: target,
          openHour: openHour,
          closeHour: closeHour,
          useDemoCatalog: useDemoCatalog,
          invoices: invoices,
        );
  });

  /// Produk asli + katalog demo, untuk menghitung ulang harga kemasan saat nota demo diedit.
  Map<String, Product> demoPricingProducts() => {
    for (final p in ref.read(productsProvider).value ?? const <Product>[]) p.id: p,
    for (final p in ref.read(demoCatalogProvider).products) p.id: p,
  };

  Future<bool> editInvoice(Invoice invoice, {required DateTime time, required List<int> qtyByLine}) => run(() {
    final edited = DemoInvoiceEditor.edit(
      invoice,
      time: time,
      qtyByLine: qtyByLine,
      products: demoPricingProducts(),
    );
    return ref.read(demoReportRepositoryProvider).updateInvoice(edited);
  });

  Future<bool> deleteInvoice(Invoice invoice) =>
      run(() => ref.read(demoReportRepositoryProvider).deleteInvoice(invoice));

  Future<bool> deleteDay(DateTime date) => run(() => ref.read(demoReportRepositoryProvider).deleteDay(date));
}

final demoDataViewModelProvider = NotifierProvider<DemoDataViewModel, AsyncValue<void>>(DemoDataViewModel.new);

enum ExportPeriod { range, month, year }

/// Rentang export: [from] inklusif, [to] eksklusif.
class ExportRange extends Equatable {
  const ExportRange._(this.period, this.from, this.to);

  /// Dari tanggal [first] sampai [last] (keduanya ikut).
  factory ExportRange.days(DateTime first, DateTime last) {
    final a = startOfDay(first.isAfter(last) ? last : first);
    final b = startOfDay(first.isAfter(last) ? first : last);
    return ExportRange._(ExportPeriod.range, a, DateTime(b.year, b.month, b.day + 1));
  }

  factory ExportRange.month(int year, int month) =>
      ExportRange._(ExportPeriod.month, DateTime(year, month), DateTime(year, month + 1));

  factory ExportRange.year(int year) => ExportRange._(ExportPeriod.year, DateTime(year), DateTime(year + 1));

  final ExportPeriod period;
  final DateTime from;
  final DateTime to;

  DateTime get lastDay => DateTime(to.year, to.month, to.day - 1);

  /// Mis. "12 Okt 2026", "1 Okt 2026 - 15 Okt 2026", "Oktober 2026", "2026".
  String get label {
    final day = DateFormat('d MMM yyyy', 'id_ID');
    return switch (period) {
      ExportPeriod.range => from == lastDay ? day.format(from) : '${day.format(from)} - ${day.format(lastDay)}',
      ExportPeriod.month => DateFormat('MMMM yyyy', 'id_ID').format(from),
      ExportPeriod.year => '${from.year}',
    };
  }

  @override
  List<Object?> get props => [period, from, to];
}

/// Export rekap penjualan (tanpa pengeluaran) ke Excel untuk rentang pilihan; mode (asli/demo) ikut laporan.
class ReportExportViewModel extends ActionViewModel {
  static String fileName(ExportRange range, ReportMode mode) =>
      'Rekap Penjualan${mode == ReportMode.demo ? ' (Demo)' : ''} ${range.label}.xlsx';

  Future<bool> exportXlsx(ExportRange range) => run(() async {
        final mode = ref.read(reportFilterProvider).mode;
        final demo = mode == ReportMode.demo;
        final invoices = demo
            ? await ref.read(demoReportRepositoryProvider).watchInvoices(range.from, range.to).first
            : await ref.read(salesRepositoryProvider).watchInvoices(from: range.from, to: range.to).first;
        if (invoices.every((i) => i.voided)) throw AppException('Tidak ada penjualan di ${range.label}.');

        final hpp = {
          for (final e in (await readReady(productCostsProvider.future)).entries) e.key: e.value.hpp,
          if (demo) ...ref.read(demoCatalogProvider).hpp,
        };
        // Nota asli: HPP yang disalin saat nota terbit, agar sama dengan laporan laba.
        final unitCosts = demo
            ? const <String, Map<String, int>>{}
            : {
                for (final c in await ref.read(salesRepositoryProvider).watchInvoiceCosts(range.from, range.to).first)
                  c.invoiceId: c.unitCostByProduct,
              };

        final rows = SalesExport.rows(
          invoices,
          unitCost: (inv, productId) => unitCosts[inv.id]?[productId] ?? hpp[productId] ?? 0,
        );
        await FilePicker.saveFile(
          fileName: fileName(range, mode),
          bytes: SalesXlsx.build(rows),
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          type: FileType.custom,
          allowedExtensions: const ['xlsx'],
        );
      });
}

final reportExportViewModelProvider =
    NotifierProvider<ReportExportViewModel, AsyncValue<void>>(ReportExportViewModel.new);
