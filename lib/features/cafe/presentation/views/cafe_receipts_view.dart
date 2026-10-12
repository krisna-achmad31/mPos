import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
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

  @override
  Widget build(BuildContext context) {
    final next = DateTime(_day.year, _day.month, _day.day + 1);
    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: const Text('Riwayat struk'),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          TextButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _day = startOfDay(picked));
            },
            child: Text(formatDate(_day)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: next.isAfter(DateTime.now()) ? null : () => _shift(1),
          ),
        ],
      ),
      body: AsyncValueView(
        value: ref.watch(invoicesInMonthProvider(startOfMonth(_day))),
        data: (all) {
          final list = all.where((i) => !i.createdAt.isBefore(_day) && i.createdAt.isBefore(next)).toList();
          if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada struk di hari ini');
          final total = list.where((i) => !i.voided).fold(0, (s, i) => s + i.totals.total);
          return ListView(
            children: [
              ListTile(
                title: Text('${list.length} struk'),
                trailing: Text(formatRupiah(total), style: Theme.of(context).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              for (final inv in list)
                ListTile(
                  title: Text('${timeOf(inv.createdAt)} · ${inv.number}'),
                  subtitle: Text(
                    '${inv.lines.map((l) => '${l.qty}× ${l.name}').join(', ')}'
                    '${inv.customerName.isEmpty ? '' : ' · ${inv.customerName}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatRupiah(inv.totals.total)),
                      Text(inv.paymentMethod?.label ?? '', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  onTap: () => context.go('/cafe/receipts/${inv.id}'),
                ),
            ],
          );
        },
      ),
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
                padding: const EdgeInsets.all(16),
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
