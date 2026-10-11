import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../products/presentation/viewmodels/product_view_models.dart';
import '../sales/presentation/viewmodels/report_view_model.dart';
import '../sales/sales_providers.dart';
import '../stock/stock_providers.dart';
import '../../core/router/app_shell.dart';

/// Ringkasan harian Owner.
class DashboardView extends ConsumerWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = startOfDay(DateTime.now());
    final invoices = ref.watch(invoicesInMonthProvider(startOfMonth(today))).value ?? const [];
    final todays = invoices.where((i) => !i.voided && !i.createdAt.isBefore(today)).toList();
    final todaySales = todays.fold(0, (s, i) => s + i.totals.total);
    final receivables = invoices.where((i) => !i.voided).fold(0, (s, i) => s + i.remaining);
    final reorder = ref.watch(reorderProductsProvider).value ?? const [];
    final pendingOrders = ref.watch(pendingOrderCountProvider);
    final pendingApprovals = ref.watch(pendingChangeCountProvider);

    Widget tile(String label, String value, IconData icon, {String? route}) => SizedBox(
          width: 220,
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: route == null ? null : () => context.go(route),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(value, style: Theme.of(context).textTheme.headlineSmall),
                    Text(label),
                  ],
                ),
              ),
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              tile('Omzet hari ini (${todays.length} nota)', formatRupiah(todaySales), Icons.trending_up, route: '/owner/invoices'),
              tile('Pesanan menunggu', '$pendingOrders', Icons.inbox, route: '/owner/orders'),
              tile('Approval tertunda', '$pendingApprovals', Icons.fact_check, route: '/owner/approvals'),
              tile('Piutang bulan ini', formatRupiah(receivables), Icons.account_balance_wallet, route: '/owner/invoices'),
            ],
          ),
          const SizedBox(height: 24),
          Text('Perlu order ulang (${reorder.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (reorder.isEmpty)
            const Text('Semua stok di atas stok minimum.')
          else
            Card(
              child: Column(
                children: [
                  for (final p in reorder)
                    ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                      title: Text(p.name),
                      subtitle: Text('Stok ${p.stock} ${p.unit} · minimum ${p.minStock}'),
                      onTap: () => context.go('/owner/products/${p.id}'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
