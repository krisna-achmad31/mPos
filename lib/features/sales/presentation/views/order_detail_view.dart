import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../pricing/pricing_providers.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/order_flow.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/order_view_models.dart';
import '../widgets/totals_table.dart';
import '../widgets/line_text.dart';

class OrderDetailView extends ConsumerWidget {
  const OrderDetailView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final back = switch (ref.watch(currentUserProvider).role) {
      UserRole.owner => '/owner/orders',
      UserRole.spv => '/spv/deliveries',
      UserRole.customer => '/shop/orders',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan'), leading: BackButton(onPressed: () => context.go(back))),
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
    final base = switch (user.role) {
      UserRole.owner => '/owner',
      UserRole.spv => '/spv',
      UserRole.customer => '/shop',
    };
    final text = Theme.of(context).textTheme;
    bool can(OrderStatus to) => OrderFlow.canMove(order, to, user);

    // Owner melihat pratinjau diskon sebelum nota terbit. Customer tidak pernah melihat ini.
    if (user.isOwner) ref.watch(discountsProvider);
    final lines = user.isOwner && order.status == OrderStatus.pending ? vm.previewLines(order) : order.lines;
    final totals = SaleCalculator.totals(lines);

    final canCancel = can(OrderStatus.cancelled);

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
            if (order.courierName.isNotEmpty)
              Row(
                spacing: 6,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 18),
                  Text('Kurir: ${order.courierName}'),
                ],
              ),
            _DeliveryProgress(status: order.status),
            if (order.note.isNotEmpty) Text('Catatan: ${order.note}'),
            if (order.cancelReason.isNotEmpty) Text('Alasan batal: ${order.cancelReason}'),
            const Divider(),
            for (final l in lines)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(l.name),
                subtitle: Text([
                  lineDetail(l),
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
                if (order.invoiceId != null && user.role != UserRole.spv)
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
                if (user.isOwner && can(OrderStatus.shipped))
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final courier = await _pickCourier(context, ref, order.courierId);
                            if (courier == null || !context.mounted) return;
                            await _act(context, ref, () => vm.assignCourier(order, courier),
                                'Diserahkan ke kurir ${courier.name}');
                          },
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(order.status == OrderStatus.shipped ? 'Ganti kurir' : 'Serahkan ke kurir'),
                  ),
                if (can(OrderStatus.delivered))
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _act(context, ref, () => vm.moveStatus(order, OrderStatus.delivered), 'Ditandai terkirim'),
                    icon: const Icon(Icons.where_to_vote_outlined),
                    label: Text(user.isOwner ? 'Tandai terkirim (atas nama kurir)' : 'Tandai sudah terkirim'),
                  ),
                if (can(OrderStatus.done))
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () => _act(context, ref, () => vm.moveStatus(order, OrderStatus.done), 'Terima kasih, pesanan diterima'),
                    icon: const Icon(Icons.task_alt),
                    label: Text(user.isOwner ? 'Tandai diterima' : 'Konfirmasi sudah diterima'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Owner memilih SPV yang mengantar pesanan.
Future<AppUser?> _pickCourier(BuildContext context, WidgetRef ref, String? currentId) => showDialog<AppUser>(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final couriers = ref.watch(couriersProvider);
          return AlertDialog(
            title: const Text('Pilih kurir'),
            content: SizedBox(
              width: 360,
              child: couriers.when(
                loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('$e'),
                data: (list) => list.isEmpty
                    ? const Text('Belum ada akun SPV. Kurir diambil dari akun ber-role SPV.')
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final c in list)
                            ListTile(
                              leading: const Icon(Icons.local_shipping_outlined),
                              title: Text(c.name),
                              subtitle: Text(c.phone.isEmpty ? c.email : c.phone),
                              trailing: c.uid == currentId ? const Icon(Icons.check) : null,
                              onTap: () => Navigator.pop(context, c),
                            ),
                        ],
                      ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal'))],
          );
        },
      ),
    );

/// Langkah pengiriman: Diproses → Dibawa kurir → Terkirim → Diterima.
class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.status});

  final OrderStatus status;

  static const _steps = [
    OrderStatus.pending,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.delivered,
    OrderStatus.done,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final current = _steps.indexOf(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Column(
              spacing: 4,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= current ? scheme.primary : scheme.surfaceContainerHighest,
                  child: Icon(i < current ? Icons.check : Icons.circle, size: 12,
                      color: i <= current ? scheme.onPrimary : scheme.outline),
                ),
                Text(_steps[i].label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < current ? scheme.primary : scheme.outlineVariant,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
