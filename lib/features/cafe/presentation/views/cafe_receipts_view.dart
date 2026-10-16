import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../reports/presentation/widgets/report_widgets.dart' show timeOf;
import '../../../sales/domain/entities/invoice.dart';
import '../../../sales/presentation/viewmodels/report_view_model.dart';
import '../../../sales/sales_providers.dart';
import '../../../settings/domain/store_settings.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../printing/receipt_layout.dart';
import '../../printing/receipt_printer.dart';
import '../cafe_view_models.dart';

/// Riwayat struk per hari, terbaru dulu.
class CafeReceiptsView extends ConsumerStatefulWidget {
  const CafeReceiptsView({super.key});

  @override
  ConsumerState<CafeReceiptsView> createState() => _CafeReceiptsViewState();
}

class _CafeReceiptsViewState extends ConsumerState<CafeReceiptsView> {
  DateTime _day = startOfDay(DateTime.now());

  void _shift(int days) => setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _day = startOfDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final next = DateTime(_day.year, _day.month, _day.day + 1);
    final isPhone = context.deviceClass == DeviceClass.phone;

    return PageScaffold(
      title: 'Riwayat struk',
      subtitle: 'Cari transaksi dan cetak ulang struk.',
      workspace: 'POS Kopi',
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Hari sebelumnya',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(-1),
            ),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(formatDate(_day)),
            ),
            IconButton(
              tooltip: 'Hari berikutnya',
              icon: const Icon(Icons.chevron_right),
              onPressed: next.isAfter(DateTime.now()) ? null : () => _shift(1),
            ),
          ],
        ),
      ],
      child: AsyncValueView(
        value: ref.watch(invoicesInMonthProvider(startOfMonth(_day))),
        data: (all) {
          final list = all.where((i) => !i.createdAt.isBefore(_day) && i.createdAt.isBefore(next)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada struk di hari ini');
          }
          final total = list.where((i) => !i.voided).fold(0, (s, i) => s + i.totals.total);
          return SectionCard(
            title: '${list.length} struk',
            subtitle: 'Total ${formatRupiah(total)}',
            child: isPhone
                ? _ReceiptCardList(receipts: list)
                : AppDataTable(
                    columns: const ['Nomor struk', 'Pelanggan', 'Waktu', 'Total', 'Pembayaran'],
                    flex: const [3, 3, 2, 2, 2],
                    emptyLabel: 'Belum ada struk di hari ini.',
                    onTap: (i) => context.go('/cafe/receipts/${list[i].id}'),
                    rows: [
                      for (final inv in list)
                        [
                          Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            inv.customerName.isEmpty ? 'Pelanggan umum' : inv.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(timeOf(inv.createdAt), style: Theme.of(context).textTheme.bodySmall),
                          Text(formatRupiah(inv.totals.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Align(alignment: Alignment.centerLeft, child: _paymentBadge(inv)),
                        ],
                    ],
                  ),
          );
        },
      ),
    );
  }
}

StatusBadge _paymentBadge(Invoice invoice) => invoice.voided
    ? const StatusBadge('Dibatalkan', tone: BadgeTone.danger)
    : const StatusBadge('Lunas', tone: BadgeTone.success, icon: Icons.check_circle_outline);

/// Daftar struk berbentuk kartu untuk layar HP.
class _ReceiptCardList extends StatelessWidget {
  const _ReceiptCardList({required this.receipts});

  final List<Invoice> receipts;

  @override
  Widget build(BuildContext context) {
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
                  _paymentBadge(inv),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Satu struk: pratinjau persis seperti cetakan thermal, dengan tombol cetak ulang.
class CafeReceiptView extends ConsumerWidget {
  const CafeReceiptView({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(cafeSettingsProvider).value ?? const CafeSettings();
    final store = ref.watch(cafeReceiptStoreProvider).value ?? const StoreSettings();
    final busy = ref.watch(receiptPrintViewModelProvider).isLoading;
    return Scaffold(
      backgroundColor: context.tokens.canvas,
      appBar: AppBar(
        title: const Text('Struk'),
        leading: BackButton(onPressed: () => context.go('/cafe/receipts')),
      ),
      body: AsyncValueView(
        value: ref.watch(invoiceProvider(invoiceId)),
        data: (Invoice? invoice) {
          if (invoice == null) return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Struk tidak ditemukan');
          final lines = ReceiptLayout.build(invoice: invoice, store: store, width: settings.charsPerLine);
          return Column(
            children: [
              // Pratinjau = PDF yang sama dengan cetakan (font monospace tidak tersedia di web).
              Expanded(
                child: PdfPreview(
                  key: ValueKey(Object.hash(settings.paperWidth, store, invoice)),
                  build: (_) => ReceiptPrinter.buildPdf(lines, settings.paperWidth),
                  useActions: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  maxPageWidth: 340,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final vm = ref.read(receiptPrintViewModelProvider.notifier);
                          final ok = await vm.printInvoice(invoice, reprint: true);
                          if (context.mounted) {
                            showMessage(context, ok ? 'Struk dicetak ulang' : vm.errorText, isError: !ok);
                          }
                        },
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak ulang'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
