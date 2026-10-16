import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/order_view_models.dart';
import '../widgets/line_text.dart';
import '../widgets/sales_badges.dart';
import '../widgets/totals_table.dart';
import 'invoice_print_view.dart';

/// Nota / invoice. Dipakai Owner dan Customer.
class InvoiceView extends ConsumerWidget {
  const InvoiceView({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(currentUserProvider).isOwner ? '/owner' : '/shop';
    final invoiceAsync = ref.watch(invoiceProvider(invoiceId));
    final invoice = invoiceAsync.value;
    return PageScaffold(
      leading: BackButton(onPressed: () => context.go('$base/invoices')),
      title: invoice == null ? 'Nota' : 'Nota ${invoice.number}',
      breadcrumb: '/  Riwayat nota / Detail',
      actions: [
        if (invoice != null)
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => InvoicePrintView(invoice: invoice)),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Cetak / PDF'),
          ),
      ],
      child: AsyncValueView(
        value: invoiceAsync,
        data: (invoice) => invoice == null
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Nota tidak ditemukan',
                message: 'Nota mungkin sudah dihapus atau tautannya salah.',
              )
            : _InvoiceBody(invoice: invoice),
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
    final tokens = context.tokens;
    final isPhone = context.deviceClass == DeviceClass.phone;

    final paper = SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          if (settings != null) ...[
            Text(settings.storeName, style: text.titleMedium?.copyWith(color: tokens.ink)),
            if (settings.address.isNotEmpty) Text(settings.address, style: text.bodySmall),
            if (settings.phone.isNotEmpty) Text(settings.phone, style: text.bodySmall),
            const Divider(height: AppSpacing.xl),
          ],
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(child: Text(invoice.number, style: text.titleMedium?.copyWith(color: tokens.ink))),
              StatusBadge(
                invoice.voided ? 'Batal' : invoice.paymentStatus.label,
                tone: invoice.voided ? BadgeTone.danger : toneForPayment(invoice.paymentStatus),
              ),
            ],
          ),
          Text(
            '${formatDateTime(invoice.createdAt)} · ${invoice.source == InvoiceSource.pos ? 'Kasir' : 'Pesanan online'}',
            style: text.bodySmall,
          ),
          Text('Pelanggan: ${invoice.customerName}', style: text.bodyMedium),
          if (invoice.salesName.isNotEmpty) Text('Sales: ${invoice.salesName}', style: text.bodySmall),
          if (invoice.isOpenCredit)
            _CreditBanner(
              invoice: invoice,
              onSettle: user.isOwner ? () => _addPayment(context, ref, settleAll: true) : null,
            )
          else if (invoice.dueDate != null && !invoice.voided)
            Text('Tempo s/d ${formatDate(invoice.dueDate!)} · sudah lunas', style: text.bodySmall),
          if (invoice.orderId case final orderId?)
            _ShippingStatus(orderId: orderId, base: user.isOwner ? '/owner' : '/shop'),
          const Divider(height: AppSpacing.xl),
          if (isPhone)
            for (final line in invoice.lines) _InvoiceLineRow(line: line)
          else
            AppDataTable(
              columns: const ['Produk', 'Qty', 'Harga', 'Jumlah'],
              flex: const [4, 2, 2, 2],
              emptyLabel: 'Belum ada produk',
              rows: [
                for (final line in invoice.lines)
                  [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(line.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            lineDetail(line),
                            if (line.discountAmount > 0) '${line.discountLabel} −${formatRupiah(line.discountAmount)}',
                          ].join(' · '),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                    Text('${line.qty} ${line.unit}'),
                    Text(formatRupiah(line.unitPrice)),
                    Text(formatRupiah(line.net), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
              ],
            ),
          const SizedBox(height: AppSpacing.md),
          TotalsTable(totals: invoice.totals),
          if (settings != null && settings.invoiceFooter.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(settings.invoiceFooter, textAlign: TextAlign.center, style: text.bodySmall),
          ],
        ],
      ),
    );

    final payment = SectionCard(
      title: 'Pembayaran',
      trailing: StatusBadge(
        invoice.voided ? 'Batal' : invoice.paymentStatus.label,
        tone: invoice.voided ? BadgeTone.danger : toneForPayment(invoice.paymentStatus),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KpiRow(
            children: [
              KpiTile(
                label: invoice.remaining > 0 ? 'Sisa tagihan' : 'Total nota',
                value: formatRupiah(invoice.remaining > 0 ? invoice.remaining : invoice.totals.total),
                icon: invoice.remaining > 0 ? Icons.account_balance_wallet_outlined : Icons.receipt_long_outlined,
                highlight: invoice.remaining > 0,
                width: null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          InfoRow(label: 'Dibayar', value: formatRupiah(invoice.paid)),
          if (invoice.change > 0) InfoRow(label: 'Kembalian', value: formatRupiah(invoice.change)),
          if (payments.isNotEmpty) ...[
            const Divider(height: AppSpacing.xl),
            Text('Riwayat pembayaran', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            for (final p in payments)
              InfoRow(
                label:
                    '${formatDateTime(p.at)} · ${p.isReversal ? 'Dibatalkan (${p.method.label} → tempo)' : p.method.label}',
                value: formatRupiah(p.amount),
              ),
          ],
          if (settings != null && settings.bankInfo.isNotEmpty && invoice.remaining > 0) ...[
            const Divider(height: AppSpacing.xl),
            Text('Pembayaran ke:\n${settings.bankInfo}', style: text.bodySmall),
          ],
          if (user.isOwner && invoice.remaining > 0 && !invoice.voided) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _addPayment(context, ref),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Catat pelunasan'),
            ),
          ],
          if (user.isOwner && invoice.remaining <= 0 && !invoice.voided) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _convertToCredit(context, ref),
              icon: const Icon(Icons.schedule),
              label: const Text('Ubah ke tempo'),
            ),
          ],
        ],
      ),
    );

    if (isPhone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [paper, payment]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        Expanded(flex: 3, child: paper),
        SizedBox(width: 360, child: payment),
      ],
    );
  }
}

class _InvoiceLineRow extends StatelessWidget {
  const _InvoiceLineRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(line.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: tokens.ink)),
                Text(
                  [
                    lineDetail(line),
                    if (line.discountAmount > 0) '${line.discountLabel} −${formatRupiah(line.discountAmount)}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(formatRupiah(line.net), style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink)),
        ],
      ),
    );
  }
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final due = invoice.dueDate;
    final overdue = invoice.isOverdue(DateTime.now());
    final fg = overdue ? tokens.danger : tokens.warning;
    final bg = overdue ? tokens.dangerTint : tokens.warningTint;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(overdue ? Icons.warning_amber_rounded : Icons.schedule, size: 18, color: fg),
          Expanded(
            child: Text(
              due == null
                  ? 'Tempo · tanggal jatuh tempo belum diisi'
                  : '${overdue ? 'Lewat jatuh tempo' : 'Tempo'} · bayar paling lambat ${formatDate(due)}',
              style: theme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          if (onSettle != null) FilledButton(onPressed: onSettle, child: const Text('Tandai sudah dibayar')),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: tokens.muted),
          Expanded(
            child: Text(
              [
                'Pengiriman: ${order.status.label}',
                if (order.courierName.isNotEmpty) 'Kurir: ${order.courierName}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
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
