import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../sales/domain/entities/invoice.dart';
import '../../data/demo_report_repository.dart';
import '../../domain/sales_report.dart';
import '../viewmodels/report_view_model.dart';
import '../widgets/report_widgets.dart';

class ReportsView extends ConsumerWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const _FilterBar(),
          if (filter.mode == ReportMode.demo) const _DemoBanner(),
          const SizedBox(height: 8),
          AsyncValueView(
            value: ref.watch(salesReportProvider),
            data: (report) => _ReportBody(report: report, period: filter.period),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportFilterProvider);
    final vm = ref.read(reportFilterProvider.notifier);
    final label = filter.period == ReportPeriod.day
        ? DateFormat('EEEE, d MMM yyyy', 'id_ID').format(filter.date)
        : DateFormat('MMMM yyyy', 'id_ID').format(filter.date);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<ReportMode>(
          segments: const [
            ButtonSegment(value: ReportMode.real, label: Text('Data asli'), icon: Icon(Icons.verified_outlined)),
            ButtonSegment(value: ReportMode.demo, label: Text('Demo'), icon: Icon(Icons.science_outlined)),
          ],
          selected: {filter.mode},
          onSelectionChanged: (s) => vm.setMode(s.first),
        ),
        SegmentedButton<ReportPeriod>(
          segments: const [
            ButtonSegment(value: ReportPeriod.day, label: Text('Harian')),
            ButtonSegment(value: ReportPeriod.month, label: Text('Bulanan')),
          ],
          selected: {filter.period},
          onSelectionChanged: (s) => vm.setPeriod(s.first),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => vm.shift(-1)),
            TextButton.icon(
              icon: const Icon(Icons.event, size: 18),
              label: Text(label),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filter.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) vm.setDate(picked);
              },
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => vm.shift(1)),
          ],
        ),
      ],
    );
  }
}

class _DemoBanner extends ConsumerWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final filter = ref.watch(reportFilterProvider);
    final day = ref.watch(demoDaysProvider).value?[DemoReportRepository.keyOf(filter.date)];
    final hasDay = day != null && filter.period == ReportPeriod.day;
    final used = ref.watch(salesReportProvider).value?.invoices.fold(0, (s, i) => s + i.totals.total) ?? 0;
    final busy = ref.watch(demoDataViewModelProvider).isLoading;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            spacing: 8,
            children: [
              Icon(Icons.science, color: scheme.onTertiaryContainer),
              Expanded(
                child: Text(
                  'MODE DEMO — data contoh hasil generator, bukan transaksi asli. '
                  'Tidak mengubah stok, nota, maupun laporan asli.',
                  style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (hasDay)
            Text(
              'Target ${formatRupiah(day.target)} · terpakai ${formatRupiah(used)} · '
              'sisa ${formatRupiah(day.target - used)} · '
              '${day.useDemoCatalog ? 'katalog demo distributor cafe' : 'produk asli'}. '
              'Ketuk ikon pensil di daftar transaksi untuk mengubah jam atau qty.',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _DemoGeneratorDialog.show(context, filter.date),
                icon: const Icon(Icons.auto_awesome),
                label: Text(hasDay ? 'Buat ulang data demo' : 'Buat data demo'),
              ),
              if (hasDay)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await confirm(
                            context,
                            title: 'Hapus data demo',
                            message: 'Hapus data demo tanggal ${formatDate(filter.date)}?',
                          );
                          if (ok) await ref.read(demoDataViewModelProvider.notifier).deleteDay(filter.date);
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus data demo hari ini'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoGeneratorDialog extends ConsumerStatefulWidget {
  const _DemoGeneratorDialog({required this.initialDate});

  final DateTime initialDate;

  static Future<void> show(BuildContext context, DateTime date) => showDialog(
    context: context,
    builder: (_) => _DemoGeneratorDialog(initialDate: date),
  );

  @override
  ConsumerState<_DemoGeneratorDialog> createState() => _DemoGeneratorDialogState();
}

class _DemoGeneratorDialogState extends ConsumerState<_DemoGeneratorDialog> {
  final _target = TextEditingController();
  late DateTime _date = widget.initialDate;
  bool _useDemoCatalog = true;
  int _open = 8;
  int _close = 21;
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final target = parseRupiah(_target.text);
    if (target <= 0) {
      setState(() => _error = 'Isi target total hari itu.');
      return;
    }
    final ok = await ref
        .read(demoDataViewModelProvider.notifier)
        .generate(date: _date, target: target, openHour: _open, closeHour: _close, useDemoCatalog: _useDemoCatalog);
    if (!mounted) return;
    if (ok) {
      ref.read(reportFilterProvider.notifier)
        ..setMode(ReportMode.demo)
        ..setPeriod(ReportPeriod.day)
        ..setDate(_date);
      Navigator.pop(context);
      showMessage(context, 'Data demo ${formatDate(_date)} dibuat');
    } else {
      setState(() => _error = '${ref.read(demoDataViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = [for (var h = 0; h <= 24; h++) h];
    final busy = ref.watch(demoDataViewModelProvider).isLoading;
    return AlertDialog(
      title: const Text('Buat data demo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text(
              'Jumlah nota, qty, dan jam pembelian dibuat bervariasi. '
              'Total hari itu tidak akan melebihi target yang Anda isi.',
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Katalog demo cafe'), icon: Icon(Icons.coffee_outlined)),
                ButtonSegment(value: false, label: Text('Produk asli'), icon: Icon(Icons.inventory_2_outlined)),
              ],
              selected: {_useDemoCatalog},
              onSelectionChanged: (v) => setState(() => _useDemoCatalog = v.first),
            ),
            Text(
              _useDemoCatalog
                  ? 'Contoh distributor ke cafe: biji kopi, susu, sirup, bubuk minuman, kemasan. '
                        'Pelanggan contoh berupa cafe, pembelian grosir.'
                  : 'Memakai produk & harga asli Anda (stok asli tidak berubah).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(formatDate(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Target total hari itu (Rp)',
                hintText: 'mis. 2500000',
                helperText: 'Batas maksimal omzet demo hari itu',
              ),
            ),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _open,
                    decoration: const InputDecoration(labelText: 'Jam buka'),
                    items: [
                      for (final h in hours.take(24))
                        DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}.00')),
                    ],
                    onChanged: (v) => setState(() => _open = v ?? _open),
                  ),
                ),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _close,
                    decoration: const InputDecoration(labelText: 'Jam tutup'),
                    items: [
                      for (final h in hours.skip(1))
                        DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}.00')),
                    ],
                    onChanged: (v) => setState(() => _close = v ?? _close),
                  ),
                ),
              ],
            ),
            Text('Data demo tanggal ini yang sudah ada akan diganti.', style: Theme.of(context).textTheme.bodySmall),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _generate, child: const Text('Buat')),
      ],
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report, required this.period});

  final SalesReport report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final busiest = r.busiestHour;
    final isDay = period == ReportPeriod.day;

    if (r.invoices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          r.isDemo
              ? 'Belum ada data demo di periode ini. Tekan "Buat data demo".'
              : 'Belum ada penjualan di periode ini.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            KpiTile(label: 'Omzet bersih', value: formatRupiah(r.netSales), icon: Icons.payments_outlined),
            KpiTile(label: 'Jumlah nota', value: '${r.invoiceCount}', icon: Icons.receipt_long_outlined),
            KpiTile(
              label: 'Rata-rata per nota',
              value: formatRupiah(r.averageTicket),
              icon: Icons.shopping_basket_outlined,
            ),
            KpiTile(label: 'Item terjual', value: formatNumber(r.itemsSold), icon: Icons.inventory_2_outlined),
            KpiTile(
              label: 'Laba kotor',
              value: formatRupiah(r.grossProfit),
              hint: 'Margin ${(r.grossMargin * 100).toStringAsFixed(1)}%',
              icon: Icons.trending_up,
            ),
            if (!r.isDemo)
              KpiTile(
                label: 'Laba bersih',
                value: formatRupiah(r.netProfit),
                hint: 'Setelah pengeluaran',
                icon: Icons.account_balance_outlined,
              ),
            KpiTile(label: 'Diskon diberikan', value: formatRupiah(r.discounts), icon: Icons.local_offer_outlined),
            KpiTile(label: 'Belum dibayar', value: formatRupiah(r.receivables), icon: Icons.hourglass_bottom),
            if (busiest != null)
              KpiTile(
                label: 'Jam paling ramai',
                value: '${hourLabel(busiest)}.00–${(busiest.start.hour + 1).toString().padLeft(2, '0')}.00',
                hint: '${busiest.count} nota · ${formatRupiah(busiest.amount)}',
                icon: Icons.schedule,
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isDay)
          SectionCard(
            title: 'Penjualan per hari',
            subtitle: 'Omzet bersih (tanpa pajak). Sentuh batang untuk detail.',
            child: TimeBarChart(buckets: r.byDay, label: dayLabel),
          ),
        SectionCard(
          title: 'Penjualan per jam',
          subtitle: isDay ? 'Sebaran transaksi hari ini' : 'Gabungan seluruh hari di bulan ini',
          child: TimeBarChart(buckets: r.byHour, label: hourLabel),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final payment = SectionCard(
              title: 'Metode pembayaran',
              child: DonutChart(items: r.byPaymentMethod),
            );
            final source = SectionCard(
              title: 'Sumber penjualan',
              child: DonutChart(items: r.bySource),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(child: payment),
                      Expanded(child: source),
                    ],
                  )
                : Column(children: [payment, source]);
          },
        ),
        SectionCard(
          title: 'Produk terlaris',
          subtitle: '${r.products.length} produk terjual · urut omzet',
          child: _ProductTable(products: r.products),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final category = SectionCard(
              title: 'Penjualan per kategori',
              child: ProportionList(items: r.byCategory, showCount: false),
            );
            final customers = SectionCard(
              title: 'Pelanggan teratas',
              child: ProportionList(items: r.topCustomers),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      Expanded(child: category),
                      Expanded(child: customers),
                    ],
                  )
                : Column(children: [category, customers]);
          },
        ),
        SectionCard(
          title: 'Laba rugi',
          child: _ProfitLoss(report: r),
        ),
        if (!r.isDemo && r.expensesByCategory.isNotEmpty)
          SectionCard(
            title: 'Pengeluaran per kategori',
            child: ProportionList(items: r.expensesByCategory),
          ),
        if (!r.isDemo)
          SectionCard(
            title: 'Stok',
            subtitle: 'Kondisi saat ini',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _row(context, 'Nilai persediaan (HPP × stok)', formatRupiah(r.inventoryValue), strong: true),
                _row(context, 'Produk perlu order ulang', '${r.reorder.length}'),
                for (final p in r.reorder.take(10)) _row(context, '  ${p.name}', 'stok ${p.stock} / min ${p.minStock}'),
              ],
            ),
          ),
        SectionCard(
          title: 'Daftar transaksi',
          subtitle: '${r.invoiceCount} nota${r.invoiceCount > 100 ? ' · 100 terbaru ditampilkan' : ''}',
          child: _TransactionList(report: r, showDate: !isDay),
        ),
      ],
    );
  }
}

Widget _row(BuildContext context, String label, String value, {bool strong = false, bool negative = false}) {
  final style = strong ? Theme.of(context).textTheme.titleSmall : null;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('${negative ? '−' : ''}$value', style: style),
      ],
    ),
  );
}

class _ProfitLoss extends StatelessWidget {
  const _ProfitLoss({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return Column(
      children: [
        _row(context, 'Penjualan (harga normal)', formatRupiah(r.grossSales)),
        _row(context, 'Diskon & promo', formatRupiah(r.discounts), negative: true),
        if (r.tax > 0) _row(context, 'Pajak (tidak dihitung sebagai omzet)', formatRupiah(r.tax)),
        const Divider(),
        _row(context, 'Omzet bersih', formatRupiah(r.netSales), strong: true),
        _row(context, 'HPP', formatRupiah(r.cost), negative: true),
        const Divider(),
        _row(context, 'Laba kotor', formatRupiah(r.grossProfit), strong: true),
        if (!r.isDemo) ...[
          _row(context, 'Pengeluaran operasional', formatRupiah(r.expenses), negative: true),
          const Divider(),
          _row(context, 'Laba bersih', formatRupiah(r.netProfit), strong: true),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Pengeluaran tidak ditampilkan di mode demo.', style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}

class _ProductTable extends StatelessWidget {
  const _ProductTable({required this.products});

  final List<ProductStat> products;

  @override
  Widget build(BuildContext context) {
    final max = products.isEmpty ? 1 : products.first.revenue;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 4, child: Text('Produk', style: text.labelMedium)),
            Expanded(
              child: Text('Qty', textAlign: TextAlign.end, style: text.labelMedium),
            ),
            Expanded(
              flex: 2,
              child: Text('Omzet', textAlign: TextAlign.end, style: text.labelMedium),
            ),
            Expanded(
              flex: 2,
              child: Text('Laba', textAlign: TextAlign.end, style: text.labelMedium),
            ),
          ],
        ),
        const Divider(),
        for (final (i, p) in products.take(20).indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              spacing: 4,
              children: [
                Row(
                  children: [
                    Expanded(flex: 4, child: Text('${i + 1}. ${p.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(child: Text(formatNumber(p.qty), textAlign: TextAlign.end)),
                    Expanded(flex: 2, child: Text(formatRupiah(p.revenue), textAlign: TextAlign.end)),
                    Expanded(flex: 2, child: Text(formatRupiah(p.profit), textAlign: TextAlign.end)),
                  ],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : p.revenue / max,
                    minHeight: 5,
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        if (products.length > 20)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('+${products.length - 20} produk lain', style: text.bodySmall),
          ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.report, required this.showDate});

  final SalesReport report;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final inv in report.invoices.take(100))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '${showDate ? '${formatDate(inv.createdAt)} ' : ''}${timeOf(inv.createdAt)} · ${inv.customerName}',
            ),
            subtitle: Text(
              '${inv.number} · ${inv.paymentMethod?.label ?? 'Pesanan online'} · '
              '${inv.lines.fold(0, (s, l) => s + l.qty)} item',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatRupiah(inv.totals.total), style: text.titleSmall),
                if (report.isDemo)
                  IconButton(
                    tooltip: 'Ubah jam / qty',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _DemoInvoiceEditDialog.show(context, inv),
                  ),
              ],
            ),
            children: [
              for (final l in inv.lines)
                _row(context, '${l.qty} × ${l.name} @${formatRupiah(l.unitPrice)}', formatRupiah(l.net)),
              if (!report.isDemo)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go('/owner/invoices/${inv.id}'),
                    child: const Text('Buka nota'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Edit satu nota demo: jam transaksi dan qty per barang.
class _DemoInvoiceEditDialog extends ConsumerStatefulWidget {
  const _DemoInvoiceEditDialog({required this.invoice});

  final Invoice invoice;

  static Future<void> show(BuildContext context, Invoice invoice) => showDialog(
    context: context,
    builder: (_) => _DemoInvoiceEditDialog(invoice: invoice),
  );

  @override
  ConsumerState<_DemoInvoiceEditDialog> createState() => _DemoInvoiceEditDialogState();
}

class _DemoInvoiceEditDialogState extends ConsumerState<_DemoInvoiceEditDialog> {
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.invoice.createdAt);
  late final _qty = [for (final l in widget.invoice.lines) TextEditingController(text: '${l.qty}')];
  String? _error;

  @override
  void dispose() {
    for (final c in _qty) {
      c.dispose();
    }
    super.dispose();
  }

  int get _previewTotal {
    var total = 0;
    for (var i = 0; i < widget.invoice.lines.length; i++) {
      total += widget.invoice.lines[i].unitPrice * (int.tryParse(_qty[i].text) ?? 0);
    }
    return total;
  }

  Future<void> _save() async {
    final d = widget.invoice.createdAt;
    final ok = await ref
        .read(demoDataViewModelProvider.notifier)
        .editInvoice(
          widget.invoice,
          time: DateTime(d.year, d.month, d.day, _time.hour, _time.minute, d.second),
          qtyByLine: [for (final c in _qty) int.tryParse(c.text) ?? 0],
        );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(demoDataViewModelProvider).error}');
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, title: 'Hapus nota demo', message: 'Hapus ${widget.invoice.number}?');
    if (!ok || !mounted) return;
    await ref.read(demoDataViewModelProvider.notifier).deleteInvoice(widget.invoice);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final busy = ref.watch(demoDataViewModelProvider).isLoading;
    return AlertDialog(
      title: Text('Ubah ${inv.number}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(inv.customerName),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text('Jam ${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}'),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              for (var i = 0; i < inv.lines.length; i++)
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: Text(
                        '${inv.lines[i].name}\n@${formatRupiah(inv.lines[i].unitPrice)} / ${inv.lines[i].unit}',
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _qty[i],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Qty'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              Text(
                'Total nota: ${formatRupiah(_previewTotal)} (qty 0 = hapus barang)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: busy ? null : _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Hapus nota'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
