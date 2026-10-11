import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../viewmodels/report_view_model.dart';
import '../widgets/month_switcher.dart';
import '../../../../core/router/app_shell.dart';

class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Laporan Keuangan'), actions: const [MonthSwitcher()]),
      body: AsyncValueView(
        value: ref.watch(reportSummaryProvider),
        data: (r) {
          final text = Theme.of(context).textTheme;
          Widget row(String label, int value, {bool strong = false, bool negative = false}) => ListTile(
                dense: !strong,
                title: Text(label, style: strong ? text.titleMedium : null),
                trailing: Text(
                  '${negative ? '−' : ''}${formatRupiah(value)}',
                  style: strong ? text.titleMedium : null,
                ),
              );
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Column(
                  children: [
                    ListTile(title: Text('Laba rugi', style: text.titleMedium), subtitle: Text('${r.invoiceCount} nota')),
                    row('Penjualan (harga normal)', r.grossSales),
                    row('Diskon & promo', r.discounts, negative: true),
                    row('Penjualan bersih (tanpa pajak)', r.netSales, strong: true),
                    row('HPP', r.cost, negative: true),
                    row('Laba kotor', r.grossProfit, strong: true),
                    row('Pengeluaran operasional', r.expenses, negative: true),
                    row('Laba bersih', r.netProfit, strong: true),
                    if (r.tax > 0) row('Pajak terkumpul', r.tax),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(title: Text('Kas masuk per metode', style: text.titleMedium)),
                    if (r.cashByMethod.isEmpty) const ListTile(dense: true, title: Text('Belum ada pembayaran')),
                    for (final e in r.cashByMethod.entries) row(e.key.label, e.value),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    ListTile(title: Text('Pengeluaran per kategori', style: text.titleMedium)),
                    if (r.expensesByCategory.isEmpty) const ListTile(dense: true, title: Text('Belum ada pengeluaran')),
                    for (final e in r.expensesByCategory.entries) row(e.key, e.value),
                  ],
                ),
              ),
              Card(
                child: Column(
                  children: [
                    row('Piutang belum lunas (nota bulan ini)', r.receivables, strong: true),
                    row('Nilai persediaan saat ini (HPP × stok)', r.inventoryValue, strong: true),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
