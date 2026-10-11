import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/pricing_providers.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/order_view_models.dart';
import '../widgets/totals_table.dart';

class OrderDetailView extends ConsumerWidget {
  const OrderDetailView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref.watch(currentUserProvider).isOwner ? '/owner' : '/shop';
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan'), leading: BackButton(onPressed: () => context.go('$base/orders'))),
      body: AsyncValueView(
        value: ref.watch(orderProvider(orderId)),
        data: (order) => order == null
            ? const Center(child: Text('Pesanan tidak ditemukan'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _OrderBody(order: order),
                  ),
                ),
              ),
      ),
    );
  }
}

class _OrderBody extends ConsumerWidget {
  const _OrderBody({required this.order});

  final SalesOrder order;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<bool> Function() action, String success) async {
    final ok = await action();
    if (!context.mounted) return;
    showMessage(context, ok ? success : '${ref.read(orderActionsViewModelProvider).error}', isError: !ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final vm = ref.read(orderActionsViewModelProvider.notifier);
    final busy = ref.watch(orderActionsViewModelProvider).isLoading;
    final base = user.isOwner ? '/owner' : '/shop';
    final text = Theme.of(context).textTheme;

    // Owner melihat pratinjau diskon sebelum nota terbit. Customer tidak pernah melihat ini.
    if (user.isOwner) ref.watch(discountsProvider);
    final lines = user.isOwner && order.status == OrderStatus.pending ? vm.previewLines(order) : order.lines;
    final totals = SaleCalculator.totals(lines);

    final canCancel = user.isOwner ? order.status.canCancel : order.status == OrderStatus.pending;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              children: [
                Expanded(child: Text(order.customerName, style: text.titleLarge)),
                Chip(label: Text(order.status.label)),
              ],
            ),
            Text(formatDateTime(order.createdAt)),
            if (order.address.isNotEmpty) Text('Kirim ke: ${order.address}'),
            if (order.note.isNotEmpty) Text('Catatan: ${order.note}'),
            if (order.cancelReason.isNotEmpty) Text('Alasan batal: ${order.cancelReason}'),
            const Divider(),
            for (final l in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.name),
                subtitle: Text([
                  '${l.qty} ${l.unit} × ${formatRupiah(l.unitPrice)}',
                  if (l.discountAmount > 0) '${l.discountLabel} −${formatRupiah(l.discountAmount)}',
                ].join(' · ')),
                trailing: Text(formatRupiah(l.net)),
              ),
            const Divider(),
            TotalsTable(totals: totals),
            if (user.isOwner && order.status == OrderStatus.pending && totals.itemDiscount > 0)
              Text('Diskon di atas baru terlihat oleh customer di invoice.', style: text.bodySmall),
            if (!user.isOwner && order.invoiceId == null)
              Text('Diskon (jika ada) dihitung saat invoice terbit.', style: text.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (order.invoiceId != null)
                  OutlinedButton.icon(
                    onPressed: () => context.go('$base/invoices/${order.invoiceId}'),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Lihat invoice'),
                  ),
                if (canCancel)
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final reason = await askReason(context, title: 'Batalkan pesanan');
                            if (reason == null || !context.mounted) return;
                            await _act(context, ref, () => vm.cancel(order, reason), 'Pesanan dibatalkan, stok dikembalikan');
                          },
                    child: const Text('Batalkan'),
                  ),
                if (user.isOwner && order.status == OrderStatus.pending)
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            final invoiceId = await vm.process(order);
                            if (!context.mounted) return;
                            if (invoiceId == null) {
                              showMessage(context, '${ref.read(orderActionsViewModelProvider).error}', isError: true);
                            } else {
                              context.go('/owner/invoices/$invoiceId');
                            }
                          },
                    child: const Text('Proses & terbitkan invoice'),
                  ),
                if (user.isOwner && order.status == OrderStatus.processing)
                  FilledButton(
                    onPressed: busy ? null : () => _act(context, ref, () => vm.setStatus(order, OrderStatus.shipped), 'Ditandai dikirim'),
                    child: const Text('Tandai dikirim'),
                  ),
                if (user.isOwner && order.status == OrderStatus.shipped)
                  FilledButton(
                    onPressed: busy ? null : () => _act(context, ref, () => vm.setStatus(order, OrderStatus.done), 'Pesanan selesai'),
                    child: const Text('Tandai selesai'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
