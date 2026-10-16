import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_layout.dart';
import '../viewmodels/report_view_model.dart';

/// Pindah bulan untuk laporan, riwayat nota, dan pengeluaran.
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportMonthProvider);
    final vm = ref.read(reportMonthProvider.notifier);
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(icon: Icons.chevron_left, tooltip: 'Bulan sebelumnya', onPressed: () => vm.shift(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              DateFormat('MMM yyyy', 'id_ID').format(month),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: tokens.ink),
            ),
          ),
          _StepButton(icon: Icons.chevron_right, tooltip: 'Bulan berikutnya', onPressed: () => vm.shift(1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: context.tokens.muted,
    );
  }
}
