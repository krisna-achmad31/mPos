import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../reports/presentation/widgets/report_widgets.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';

/// Ringkasan Owner Kopi: omzet hari ini, bahan menipis, masa premium.
class CafeDashboardView extends ConsumerWidget {
  const CafeDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = startOfDay(now);
    final invoices = (ref.watch(invoicesInMonthProvider(startOfMonth(now))).value ?? const [])
        .where((i) => !i.voided && !i.createdAt.isBefore(today))
        .toList();
    final omzet = invoices.fold(0, (s, i) => s + i.totals.total);
    final cups = invoices.fold(0, (s, i) => s + i.lines.fold(0, (a, l) => a + l.qty));
    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final low = ingredients.where((i) => i.isLow).toList();
    final stockValue = ingredients.fold(0.0, (s, i) => s + i.stockValue);
    final until = ref.watch(myCafeProvider).value?.premiumUntil;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Dashboard Kopi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              KpiTile(label: 'Omzet hari ini', value: formatRupiah(omzet), icon: Icons.payments_outlined),
              KpiTile(label: 'Struk hari ini', value: '${invoices.length}', icon: Icons.receipt_long_outlined),
              KpiTile(label: 'Menu terjual', value: formatNumber(cups), icon: Icons.local_cafe_outlined),
              KpiTile(label: 'Nilai stok bahan', value: formatRupiah(stockValue.round()), icon: Icons.inventory_2_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(onPressed: () => context.go('/cafe/pos'), icon: const Icon(Icons.point_of_sale), label: const Text('Buka kasir')),
              OutlinedButton.icon(onPressed: () => context.go('/cafe/menu/new'), icon: const Icon(Icons.add), label: const Text('Menu baru')),
              OutlinedButton.icon(onPressed: () => context.go('/cafe/stock'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Stok bahan')),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  leading: Icon(Icons.warning_amber, color: low.isEmpty ? null : Theme.of(context).colorScheme.error),
                  title: Text(low.isEmpty ? 'Semua stok bahan aman' : '${low.length} bahan menipis'),
                  subtitle: const Text('Stok di bawah batas minimum. Belanja ke distributor untuk menambah otomatis.'),
                ),
                for (final i in low.take(8))
                  ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 72, right: 16),
                    title: Text(i.name),
                    trailing: Text('${formatQty(i.stock)} / min ${formatQty(i.minStock)} ${i.unit}'),
                  ),
              ],
            ),
          ),
          if (until != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Premium aktif sampai ${formatDate(until)}', style: text.bodySmall),
            ),
        ],
      ),
    );
  }
}
