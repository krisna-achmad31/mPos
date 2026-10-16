import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/app_layout.dart';
import '../../core/widgets/status_badge.dart';
import '../products/presentation/viewmodels/product_view_models.dart';
import '../sales/domain/entities/sales_order.dart';
import '../sales/presentation/widgets/sales_badges.dart';
import '../sales/presentation/viewmodels/report_view_model.dart';
import '../sales/sales_providers.dart';
import '../stock/stock_providers.dart';

/// Ringkasan harian Owner (padanan frame `01 · Owner / Ringkasan`).
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
    final orders = ref.watch(ordersProvider).value ?? const <SalesOrder>[];
    final recent = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final isPhone = context.deviceClass == DeviceClass.phone;

    return PageScaffold(
      title: 'Ringkasan',
      subtitle: 'Pantau penjualan, pesanan, dan stok distributor hari ini.',
      actions: [
        OutlinedButton(onPressed: () => context.go('/owner/reports'), child: const Text('Laporan')),
        FilledButton.icon(
          onPressed: () => context.go('/owner/pos'),
          icon: const Icon(Icons.point_of_sale, size: 18),
          label: const Text('Buka kasir'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KpiRow(
            children: [
              KpiTile(
                label: 'Omzet hari ini',
                value: formatRupiah(todaySales),
                hint: '${todays.length} nota terbit hari ini',
                icon: Icons.trending_up,
                highlight: true,
                width: null,
                onTap: () => context.go('/owner/invoices'),
              ),
              KpiTile(
                label: 'Pesanan menunggu',
                value: '$pendingOrders',
                hint: 'Perlu diproses',
                icon: Icons.inbox_outlined,
                width: null,
                onTap: () => context.go('/owner/orders'),
              ),
              KpiTile(
                label: 'Approval tertunda',
                value: '$pendingApprovals',
                hint: 'Pengajuan stok SPV',
                icon: Icons.fact_check_outlined,
                width: null,
                onTap: () => context.go('/owner/approvals'),
              ),
              KpiTile(
                label: 'Piutang bulan ini',
                value: formatRupiah(receivables),
                hint: 'Belum dibayar',
                icon: Icons.account_balance_wallet_outlined,
                width: null,
                onTap: () => context.go('/owner/invoices'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: 'Pesanan terbaru',
            subtitle: 'Pesanan online yang masuk dari pelanggan.',
            trailing: TextButton(onPressed: () => context.go('/owner/orders'), child: const Text('Lihat semua')),
            child: isPhone
                ? _OrderList(
                    orders: recent.take(4).toList(),
                    onTap: (o) => context.go('/owner/orders/${o.id}'),
                  )
                : AppDataTable(
                    columns: const ['Pesanan', 'Pelanggan', 'Waktu', 'Total', 'Status'],
                    flex: const [2, 3, 2, 2, 2],
                    onTap: (i) => context.go('/owner/orders/${recent[i].id}'),
                    emptyLabel: 'Belum ada pesanan masuk.',
                    rows: [
                      for (final o in recent.take(6))
                        [
                          Text(shortOrderId(o.id)),
                          Text(
                            o.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(formatDateTime(o.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          Text(formatRupiah(o.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Align(alignment: Alignment.centerLeft, child: orderBadge(o.status)),
                        ],
                    ],
                  ),
          ),
          SectionCard(
            title: 'Perlu order ulang (${reorder.length})',
            subtitle: 'Stok produk sudah di bawah batas minimum.',
            child: reorder.isEmpty
                ? Row(
                    spacing: 8,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: context.tokens.success),
                      const Text('Semua stok di atas stok minimum.'),
                    ],
                  )
                : Column(
                    children: [
                      for (final p in reorder)
                        InkWell(
                          onTap: () => context.go('/owner/products/${p.id}'),
                          borderRadius: BorderRadius.circular(AppRadius.control),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              spacing: AppSpacing.md,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Minimum ${p.minStock} ${p.unit}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  'Stok ${p.stock} ${p.unit}',
                                  tone: p.stock <= 0 ? BadgeTone.danger : BadgeTone.warning,
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Nomor pesanan ringkas untuk ditampilkan di tabel.
String shortOrderId(String id) => '#${id.length > 6 ? id.substring(0, 6).toUpperCase() : id.toUpperCase()}';

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.onTap});

  final List<SalesOrder> orders;
  final ValueChanged<SalesOrder> onTap;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Text('Belum ada pesanan masuk.', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: [
        for (final o in orders)
          InkWell(
            onTap: () => onTap(o),
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${shortOrderId(o.id)} · ${formatDateTime(o.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(formatRupiah(o.subtotal), style: Theme.of(context).textTheme.bodyMedium),
                  orderBadge(o.status),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
