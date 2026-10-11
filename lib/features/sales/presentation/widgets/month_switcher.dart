import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../viewmodels/report_view_model.dart';

/// Pindah bulan untuk laporan, riwayat nota, dan pengeluaran.
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportMonthProvider);
    final vm = ref.read(reportMonthProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => vm.shift(-1)),
        Text(DateFormat('MMM yyyy', 'id_ID').format(month)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => vm.shift(1)),
      ],
    );
  }
}
