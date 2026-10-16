import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../reports/presentation/widgets/report_widgets.dart' show timeOf;
import '../../../sales/domain/entities/invoice.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';

/// Ringkasan Owner Kopi: omzet, struk terbaru, dan stok bahan yang menipis.
class CafeDashboardView extends ConsumerWidget {
  const CafeDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = startOfDay(now);
    final invoices = (ref.watch(invoicesInMonthProvider(startOfMonth(now))).value ?? const [])
        .where((i) => !i.voided && !i.createdAt.isBefore(today))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final omzet = invoices.fold(0, (s, i) => s + i.totals.total);
    final cups = invoices.fold(0, (s, i) => s + i.lines.fold(0, (a, l) => a + l.qty));
    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final low = ingredients.where((i) => i.isLow).toList();
    final stockValue = ingredients.fold(0.0, (s, i) => s + i.stockValue);
    final until = ref.watch(myCafeProvider).value?.premiumUntil;
    final isPhone = context.deviceClass == DeviceClass.phone;

    final sold = <String, int>{};
    for (final inv in invoices) {
      for (final line in inv.lines) {
        sold[line.name] = (sold[line.name] ?? 0) + line.qty;
      }
    }
    final ranked = sold.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.isEmpty ? null : ranked.first;

    return PageScaffold(
      title: 'Ringkasan',
      subtitle: 'Pantau penjualan, menu, dan stok bahan kedai hari ini.',
      workspace: 'POS Kopi',
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.go('/cafe/menu/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Menu baru'),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/cafe/stock'),
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: const Text('Stok bahan'),
        ),
        FilledButton.icon(
          onPressed: () => context.go('/cafe/pos'),
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
                value: formatRupiah(omzet),
                hint: '${invoices.length} struk · ${formatNumber(cups)} porsi',
                icon: Icons.trending_up,
                highlight: true,
                width: null,
                onTap: () => context.go('/cafe/receipts'),
              ),
              KpiTile(
                label: 'Struk hari ini',
                value: '${invoices.length}',
                hint: 'Transaksi kasir',
                icon: Icons.receipt_long_outlined,
                width: null,
                onTap: () => context.go('/cafe/receipts'),
              ),
              KpiTile(
                label: 'Menu terlaris',
                value: top?.key ?? '—',
                hint: top == null ? 'Belum ada penjualan' : '${formatNumber(top.value)} porsi hari ini',
                icon: Icons.local_fire_department_outlined,
                width: null,
                onTap: () => context.go('/cafe/menu'),
              ),
              KpiTile(
                label: 'Bahan menipis',
                value: '${low.length} bahan',
                hint: low.isEmpty ? 'Semua stok aman' : 'Nilai stok ${formatRupiah(stockValue.round())}',
                icon: Icons.inventory_2_outlined,
                width: null,
                onTap: () => context.go('/cafe/stock'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionCard(
            title: 'Struk terbaru',
            subtitle: 'Transaksi kasir hari ini.',
            trailing: TextButton(onPressed: () => context.go('/cafe/receipts'), child: const Text('Lihat semua')),
            child: isPhone
                ? _ReceiptList(receipts: invoices.take(4).toList())
                : AppDataTable(
                    columns: const ['Nomor struk', 'Waktu', 'Total', 'Metode'],
                    flex: const [3, 2, 2, 2],
                    emptyLabel: 'Belum ada struk hari ini.',
                    onTap: (i) => context.go('/cafe/receipts/${invoices[i].id}'),
                    rows: [
                      for (final inv in invoices.take(6))
                        [
                          Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(timeOf(inv.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          Text(formatRupiah(inv.totals.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(inv.paymentMethod?.label ?? '—'),
                          ),
                        ],
                    ],
                  ),
          ),
          SectionCard(
            title: low.isEmpty ? 'Stok bahan aman' : 'Bahan perlu diisi (${low.length})',
            subtitle: 'Stok di bawah batas minimum. Belanja ke distributor untuk menambah otomatis.',
            trailing: TextButton(onPressed: () => context.go('/cafe/stock'), child: const Text('Kelola')),
            child: low.isEmpty
                ? Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Icon(Icons.check_circle_outline, size: 18, color: context.tokens.success),
                      const Text('Semua stok bahan di atas batas minimum.'),
                    ],
                  )
                : Column(
                    children: [
                      for (final i in low)
                        InkWell(
                          onTap: () => context.go('/cafe/stock'),
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
                                        i.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Minimum ${formatQty(i.minStock)} ${i.unit}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  'Sisa ${formatQty(i.stock)} ${i.unit}',
                                  tone: i.stock <= 0 ? BadgeTone.danger : BadgeTone.warning,
                                  icon: Icons.warning_amber_rounded,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (until != null)
            Text(
              'Premium aktif sampai ${formatDate(until)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
            ),
        ],
      ),
    );
  }
}

/// Daftar struk ringkas untuk layar HP.
class _ReceiptList extends StatelessWidget {
  const _ReceiptList({required this.receipts});

  final List<Invoice> receipts;

  @override
  Widget build(BuildContext context) {
    if (receipts.isEmpty) {
      return Text('Belum ada struk hari ini.', style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      children: [
        for (final inv in receipts)
          InkWell(
            onTap: () => context.go('/cafe/receipts/${inv.id}'),
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
                          inv.number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${timeOf(inv.createdAt)} · ${inv.customerName.isEmpty ? 'Pelanggan umum' : inv.customerName}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(formatRupiah(inv.totals.total), style: Theme.of(context).textTheme.bodyMedium),
                  StatusBadge(inv.paymentMethod?.label ?? '—'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
