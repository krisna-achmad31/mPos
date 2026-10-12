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
import 'invoice_print_view.dart';

/// Nota / invoice. Dipakai Owner dan Customer.
class InvoiceView extends ConsumerWidget {
  const InvoiceView({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(currentUserProvider).isOwner ? '/owner' : '/shop';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice'),
        leading: BackButton(onPressed: () => context.go('$base/invoices')),
        actions: [
          if (ref.watch(invoiceProvider(invoiceId)).value case final invoice?)
            TextButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Cetak / PDF'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => InvoicePrintView(invoice: invoice)),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
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

  /// Catat pelunasan: uang masuk (Tunai / Transfer / QRIS) atau jadikan tempo dengan tanggal jatuh tempo.
  Future<void> _addPayment(BuildContext context, WidgetRef ref, {bool settleAll = false}) async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(invoice: invoice, settleAll: settleAll),
    );
    if (result == null || !context.mounted) return;
    final vm = ref.read(orderActionsViewModelProvider.notifier);
    final dueDate = result.dueDate;
    final ok = dueDate != null
        ? await vm.setCreditTerm(invoice, dueDate)
        : await vm.addPayment(invoice, result.amount, result.method);
    if (!context.mounted) return;
    final done = dueDate != null ? 'Tempo dicatat, jatuh tempo ${formatDate(dueDate)}' : 'Pembayaran dicatat';
    showMessage(context, ok ? done : '${ref.read(orderActionsViewModelProvider).error}', isError: !ok);
  }

  /// Terlanjur dicatat lunas tapi customer minta tempo.
  Future<void> _convertToCredit(BuildContext context, WidgetRef ref) async {
    final dueDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => _ConvertToCreditDialog(invoice: invoice),
    );
    if (dueDate == null || !context.mounted) return;
    final ok = await ref.read(orderActionsViewModelProvider.notifier).setCreditTerm(invoice, dueDate);
    if (!context.mounted) return;
    showMessage(
      context,
      ok ? 'Diubah ke tempo, jatuh tempo ${formatDate(dueDate)}' : '${ref.read(orderActionsViewModelProvider).error}',
      isError: !ok,
    );
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
            if (invoice.isOpenCredit)
              _CreditBanner(
                invoice: invoice,
                onSettle: user.isOwner ? () => _addPayment(context, ref, settleAll: true) : null,
              )
            else if (invoice.dueDate != null && !invoice.voided)
              Text('Tempo s/d ${formatDate(invoice.dueDate!)} · sudah lunas', style: text.bodySmall),
            if (invoice.orderId case final orderId?) _ShippingStatus(orderId: orderId, base: user.isOwner ? '/owner' : '/shop'),
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
              for (final p in payments)
                _row(
                  '${formatDateTime(p.at)} · ${p.isReversal ? 'Dibatalkan (${p.method.label} → tempo)' : p.method.label}',
                  formatRupiah(p.amount),
                ),
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
            if (user.isOwner && invoice.remaining <= 0 && !invoice.voided) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _convertToCredit(context, ref),
                icon: const Icon(Icons.schedule),
                label: const Text('Ubah ke tempo'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(children: [Expanded(child: Text(label)), Text(value)]);
}

class _PaymentInput {
  const _PaymentInput.payment(this.method, this.amount) : dueDate = null;
  const _PaymentInput.credit(DateTime this.dueDate)
      : method = PaymentMethod.credit,
        amount = 0;

  final PaymentMethod method;
  final int amount;

  /// Diisi bila dijadikan tempo.
  final DateTime? dueDate;
}

/// [settleAll]: dari tombol "Tandai sudah dibayar" -> nominal = seluruh sisa, tanpa pilihan Tempo.
class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.invoice, required this.settleAll});

  final Invoice invoice;
  final bool settleAll;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(text: '${widget.invoice.remaining}');
  var _method = PaymentMethod.cash;
  late DateTime? _dueDate = widget.invoice.dueDate;
  String? _error;

  bool get _isCredit => _method == PaymentMethod.credit;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate != null && !_dueDate!.isBefore(today) ? _dueDate! : today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Tanggal jatuh tempo',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  void _submit() {
    if (_isCredit) {
      final due = _dueDate;
      if (due == null) return setState(() => _error = 'Pilih tanggal jatuh tempo');
      Navigator.pop(context, _PaymentInput.credit(due));
    } else {
      Navigator.pop(context, _PaymentInput.payment(_method, parseRupiah(_amount.text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = [...PaymentMethod.settlement, if (!widget.settleAll) PaymentMethod.credit];
    return AlertDialog(
      title: Text(widget.settleAll ? 'Tandai sudah dibayar' : 'Catat pelunasan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text('Sisa tagihan ${formatRupiah(widget.invoice.remaining)}'),
          DropdownButtonFormField<PaymentMethod>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Metode'),
            items: [for (final m in methods) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (m) => setState(() {
              _method = m ?? _method;
              _error = null;
            }),
          ),
          if (_isCredit)
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Jatuh tempo',
                  errorText: _error,
                  suffixIcon: const Icon(Icons.event),
                ),
                child: Text(_dueDate == null ? 'Pilih tanggal' : formatDate(_dueDate!)),
              ),
            )
          else
            TextField(
              controller: _amount,
              enabled: !widget.settleAll,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
            ),
          if (_isCredit)
            Text(
              'Belum ada uang masuk. Nota masuk filter Tempo sampai ditandai sudah dibayar.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}

/// Info tempo di nota + tombol untuk menandai sudah dibayar.
class _CreditBanner extends StatelessWidget {
  const _CreditBanner({required this.invoice, this.onSettle});

  final Invoice invoice;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = invoice.dueDate;
    final overdue = invoice.isOverdue(DateTime.now());
    final fg = overdue ? scheme.onErrorContainer : scheme.onTertiaryContainer;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: overdue ? scheme.errorContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          Icon(overdue ? Icons.warning_amber_rounded : Icons.schedule, color: fg),
          Expanded(
            child: Text(
              due == null
                  ? 'Tempo · tanggal jatuh tempo belum diisi'
                  : '${overdue ? 'Lewat jatuh tempo' : 'Tempo'} · bayar paling lambat ${formatDate(due)}',
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          if (onSettle != null)
            FilledButton(onPressed: onSettle, child: const Text('Tandai sudah dibayar')),
        ],
      ),
    );
  }
}

/// Status pengiriman pesanan online + jalan pintas ke halaman pesanan (tugaskan kurir, dll.).
class _ShippingStatus extends ConsumerWidget {
  const _ShippingStatus({required this.orderId, required this.base});

  final String orderId;
  final String base;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).value;
    if (order == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        spacing: 12,
        children: [
          const Icon(Icons.local_shipping_outlined),
          Expanded(
            child: Text(
              [
                'Pengiriman: ${order.status.label}',
                if (order.courierName.isNotEmpty) 'Kurir: ${order.courierName}',
              ].join(' · '),
            ),
          ),
          TextButton(
            onPressed: () => context.go('$base/orders/$orderId'),
            child: const Text('Lihat pengiriman'),
          ),
        ],
      ),
    );
  }
}

/// Nota lunas -> tempo: pilih tanggal jatuh tempo; pembayaran sebelumnya dibatalkan.
class _ConvertToCreditDialog extends StatefulWidget {
  const _ConvertToCreditDialog({required this.invoice});

  final Invoice invoice;

  @override
  State<_ConvertToCreditDialog> createState() => _ConvertToCreditDialogState();
}

class _ConvertToCreditDialogState extends State<_ConvertToCreditDialog> {
  DateTime? _dueDate;
  String? _error;

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Tanggal jatuh tempo',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return AlertDialog(
      title: const Text('Ubah ke tempo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text(
            'Pembayaran ${formatRupiah(inv.paid)}${inv.paymentMethod == null ? '' : ' (${inv.paymentMethod!.label})'} '
            'dibatalkan dan tetap tercatat di riwayat pembayaran. '
            'Seluruh tagihan ${formatRupiah(inv.totals.total)} menjadi tempo. Pengiriman tidak terpengaruh.',
          ),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(labelText: 'Jatuh tempo', errorText: _error, suffixIcon: const Icon(Icons.event)),
              child: Text(_dueDate == null ? 'Pilih tanggal' : formatDate(_dueDate!)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => _dueDate == null
              ? setState(() => _error = 'Pilih tanggal jatuh tempo')
              : Navigator.pop(context, _dueDate),
          child: const Text('Ubah ke tempo'),
        ),
      ],
    );
  }
}
