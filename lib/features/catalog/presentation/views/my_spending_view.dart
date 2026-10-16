import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../products/presentation/views/product_list_view.dart' show categoryIcon;
import '../../../reports/presentation/widgets/report_widgets.dart'
    show DonutChart, ProportionList, TimeBarChart, dayLabel;
import '../../domain/customer_spending.dart';
import '../viewmodels/customer_spending_view_model.dart';

/// Pelanggan: apa saja yang sudah dipesan dalam sebulan, berapa nilainya, per kategori
/// (padanan frame `33 · Pelanggan / Belanja saya`, `75 · Mobile / Belanja saya`).
class MySpendingView extends ConsumerWidget {
  const MySpendingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(spendingMonthProvider);
    final vm = ref.read(spendingMonthProvider.notifier);
    return PageScaffold(
      title: 'Belanja saya',
      subtitle: 'Ringkasan pembelian Anda dari distributor.',
      actions: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            IconButton(onPressed: () => vm.shift(-1), icon: const Icon(Icons.chevron_left)),
            Text(DateFormat('MMMM yyyy', 'id_ID').format(month), style: Theme.of(context).textTheme.titleSmall),
            IconButton(onPressed: () => vm.shift(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
      child: AsyncValueView(
        value: ref.watch(customerSpendingProvider),
        data: (s) => s.orderCount == 0
            ? const EmptyState(icon: Icons.shopping_bag_outlined, message: 'Belum ada pesanan di bulan ini')
            : _Body(spending: s),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.spending});

  final CustomerSpending spending;

  @override
  Widget build(BuildContext context) {
    final s = spending;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiRow(
          children: [
            KpiTile(
              label: 'Total belanja',
              value: formatRupiah(s.total),
              hint: '${s.orderCount} pesanan bulan ini',
              icon: Icons.payments_outlined,
              highlight: true,
              width: null,
            ),
            KpiTile(
              label: 'Jumlah pesanan',
              value: '${s.orderCount}',
              hint: 'Pesanan pada bulan ini',
              icon: Icons.receipt_long_outlined,
              width: null,
            ),
            KpiTile(
              label: 'Item dibeli',
              value: formatNumber(s.itemCount),
              hint: 'Total kuantitas',
              icon: Icons.inventory_2_outlined,
              width: null,
            ),
            KpiTile(
              label: 'Kategori',
              value: '${s.byCategory.length}',
              hint: s.byCategory.isEmpty ? null : 'Terbesar: ${s.byCategory.first.name}',
              icon: Icons.category_outlined,
              width: null,
            ),
          ],
        ),
        if (s.pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              '${s.pendingCount} pesanan belum diproses: nilainya masih harga katalog, '
              'nilai final (termasuk diskon) mengikuti invoice.',
              style: text.bodySmall,
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(builder: (context, c) {
          final donut = SectionCard(title: 'Belanja per kategori', child: DonutChart(items: s.byCategory));
          final bars = SectionCard(
            title: 'Proporsi kategori',
            subtitle: 'Nilai belanja · persentase · jumlah pesanan',
            child: ProportionList(items: s.byCategory),
          );
          return c.maxWidth >= 900
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: AppSpacing.md, children: [
                  Expanded(child: donut),
                  Expanded(child: bars),
                ])
              : Column(children: [donut, bars]);
        }),
        SectionCard(
          title: 'Belanja per hari',
          subtitle: 'Sentuh batang untuk detail',
          child: TimeBarChart(buckets: s.byDay, label: dayLabel),
        ),
        SectionCard(
          title: 'Rincian barang per kategori',
          child: Column(
            children: [
              for (final cat in s.byCategory)
                ExpansionTile(
                  initiallyExpanded: s.byCategory.length <= 3,
                  tilePadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(categoryIcon(cat.name), size: 20)),
                  title: Text(cat.name, style: text.titleSmall),
                  subtitle: Text('${s.itemsByCategory[cat.name]!.length} jenis barang'),
                  trailing: Text(formatRupiah(cat.amount), style: text.titleSmall),
                  children: [
                    for (final item in s.itemsByCategory[cat.name]!)
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 56),
                        title: Text(item.name),
                        subtitle: Text('${formatNumber(item.qty)} ${item.unit}'),
                        trailing: Text(formatRupiah(item.amount)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
