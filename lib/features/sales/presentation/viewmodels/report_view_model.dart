import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../domain/entities/invoice.dart';
import '../../sales_providers.dart';

/// Bulan aktif untuk riwayat nota dan pengeluaran.
class ReportMonthViewModel extends Notifier<DateTime> {
  @override
  DateTime build() => startOfMonth(DateTime.now());

  void shift(int months) => state = DateTime(state.year, state.month + months);
}

final reportMonthProvider = NotifierProvider<ReportMonthViewModel, DateTime>(ReportMonthViewModel.new);

final invoicesInMonthProvider = StreamProvider.family<List<Invoice>, DateTime>((ref, month) => ref
    .watch(salesRepositoryProvider)
    .watchInvoices(from: startOfMonth(month), to: startOfNextMonth(month)));
