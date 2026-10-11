import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/order_view_models.dart';
import '../widgets/totals_table.dart';
import '../widgets/line_text.dart';

/// Nota / invoice. Dipakai Owner dan Customer.
class InvoiceView extends ConsumerWidget {
  const InvoiceView({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(currentUserProvider).isOwner ? '/owner' : '/shop';
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice'), leading: BackButton(onPressed: () => context.go('$base/invoices'))),
      body: AsyncValueView(
        value: ref.watch(invoiceProvider(invoiceId)),
        data: (invoice) => invoice == null
            ? const Center(child: Text('Invoice tidak ditemukan'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _InvoiceBody(invoice: invoice),
                  ),
                ),
              ),
      ),
    );
  }
}

class _InvoiceBody extends ConsumerWidget {
  const _InvoiceBody({required this.invoice});

  final Invoice invoice;

  Future<void> _addPayment(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: '${invoice.remaining}');
    var method = PaymentMethod.cash;
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Catat pelunasan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Text('Sisa tagihan ${formatRupiah(invoice.remaining)}'),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
              ),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                items: const [
                  DropdownMenuItem(value: PaymentMethod.cash, child: Text('Tunai')),
                  DropdownMenuItem(value: PaymentMethod.transfer, child: Text('Transfer / QRIS')),
                ],
                onChanged: (m) => setState(() => method = m ?? method),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, parseRupiah(controller.text)), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (amount == null) return;
    final ok = await ref.read(orderActionsViewModelProvider.notifier).addPayment(invoice, amount, method);
    if (!context.mounted) return;
    showMessage(context, ok ? 'Pembayaran dicatat' : '${ref.read(orderActionsViewModelProvider).error}', isError: !ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(storeSettingsProvider).value;
    final payments = ref.watch(paymentsProvider(invoice.id)).value ?? const <PaymentRecord>[];
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            if (settings != null) ...[
              Text(settings.storeName, style: text.titleLarge),
              if (settings.address.isNotEmpty) Text(settings.address),
              if (settings.phone.isNotEmpty) Text(settings.phone),
              const Divider(),
            ],
            Row(
              children: [
                Expanded(child: Text(invoice.number, style: text.titleMedium)),
                Chip(label: Text(invoice.voided ? 'Batal' : invoice.paymentStatus.label)),
              ],
            ),
            Text('${formatDateTime(invoice.createdAt)} · ${invoice.source == InvoiceSource.pos ? 'Kasir' : 'Pesanan online'}'),
            Text('Pelanggan: ${invoice.customerName}'),
            if (invoice.salesName.isNotEmpty) Text('Sales: ${invoice.salesName}'),
            const Divider(),
            for (final line in invoice.lines) ...[
              Row(
                children: [
                  Expanded(child: Text(line.name)),
                  Text(formatRupiah(line.gross)),
                ],
              ),
              Text(lineDetail(line), style: text.bodySmall),
              if (line.discountAmount > 0)
                Row(
                  children: [
                    Expanded(child: Text('  ${line.discountLabel}', style: text.bodySmall)),
                    Text('−${formatRupiah(line.discountAmount)}', style: text.bodySmall),
                  ],
                ),
            ],
            const Divider(),
            TotalsTable(totals: invoice.totals),
            const SizedBox(height: 8),
            _row('Dibayar', formatRupiah(invoice.paid)),
            if (invoice.change > 0) _row('Kembalian', formatRupiah(invoice.change)),
            if (invoice.remaining > 0) _row('Sisa tagihan', formatRupiah(invoice.remaining)),
            if (payments.isNotEmpty) ...[
              const Divider(),
              Text('Riwayat pembayaran', style: text.titleSmall),
              for (final p in payments) _row('${formatDateTime(p.at)} · ${p.method.label}', formatRupiah(p.amount)),
            ],
            if (settings != null && settings.bankInfo.isNotEmpty && invoice.remaining > 0) ...[
              const Divider(),
              Text('Pembayaran ke:\n${settings.bankInfo}'),
            ],
            if (settings != null && settings.invoiceFooter.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(settings.invoiceFooter, textAlign: TextAlign.center, style: text.bodySmall),
            ],
            if (user.isOwner && invoice.remaining > 0 && !invoice.voided) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _addPayment(context, ref),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Catat pelunasan'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(children: [Expanded(child: Text(label)), Text(value)]);
}
