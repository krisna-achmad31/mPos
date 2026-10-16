import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/app_timeline.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../pricing/pricing_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/services/order_flow.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/order_view_models.dart';
import '../widgets/line_text.dart';
import '../widgets/sales_badges.dart';
import '../widgets/totals_table.dart';

class OrderDetailView extends ConsumerWidget {
  const OrderDetailView({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final back = switch (ref.watch(currentUserProvider).role) {
      UserRole.owner => '/owner/orders',
      UserRole.spv => '/spv/deliveries',
      UserRole.customer || UserRole.cafeOwner || UserRole.cashier => '/shop/orders',
    };
    return PageScaffold(
      leading: BackButton(onPressed: () => context.go(back)),
      title: 'Detail pesanan',
      breadcrumb: '/  Pesanan / Detail',
      child: AsyncValueView(
        value: ref.watch(orderProvider(orderId)),
        data: (order) => order == null
            ? const EmptyState(
                icon: Icons.search_off,
                title: 'Pesanan tidak ditemukan',
                message: 'Pesanan mungkin sudah dihapus atau tautannya salah.',
              )
            : _OrderBody(order: order),
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
      UserRole.customer || UserRole.cafeOwner || UserRole.cashier => '/shop',
    };
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    bool can(OrderStatus to) => OrderFlow.canMove(order, to, user);

    // Owner melihat pratinjau diskon sebelum nota terbit. Customer tidak pernah melihat ini.
    if (user.isOwner) ref.watch(discountsProvider);
    final lines = user.isOwner && order.status == OrderStatus.pending ? vm.previewLines(order) : order.lines;
    final totals = SaleCalculator.totals(lines);
    final itemCount = lines.fold<int>(0, (sum, l) => sum + l.qty);

    final canCancel = can(OrderStatus.cancelled);

    final products = SectionCard(
      title: 'Produk pesanan',
      subtitle: '$itemCount item',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (context.deviceClass == DeviceClass.phone)
            for (final l in lines) _LineRow(line: l)
          else
            AppDataTable(
              columns: const ['Produk', 'Jumlah', 'Harga', 'Subtotal'],
              flex: const [4, 2, 2, 2],
              emptyLabel: 'Belum ada produk',
              rows: [
                for (final l in lines)
                  [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            lineDetail(l),
                            if (l.discountAmount > 0) '${l.discountLabel} −${formatRupiah(l.discountAmount)}',
                          ].join(' · '),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                    Text('${l.qty} ${l.unit}'),
                    Text(formatRupiah(l.unitPrice)),
                    Text(formatRupiah(l.net), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
              ],
            ),
          const SizedBox(height: AppSpacing.lg),
          TotalsTable(totals: totals),
          if (user.isOwner && order.status == OrderStatus.pending && totals.itemDiscount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Diskon di atas baru terlihat oleh customer di invoice.', style: text.bodySmall),
          ],
          if (!user.isOwner && order.invoiceId == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Diskon (jika ada) dihitung saat invoice terbit.', style: text.bodySmall),
          ],
        ],
      ),
    );

    final actions = <Widget>[
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
                  await _act(context, ref, () => vm.assignCourier(order, courier), 'Diserahkan ke kurir ${courier.name}');
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
    ];

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KpiRow(
          children: [
            KpiTile(
              label: 'Total pesanan',
              value: formatRupiah(totals.total),
              hint: '$itemCount item',
              icon: Icons.receipt_long_outlined,
              highlight: true,
              width: null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SectionCard(
          title: 'Pelanggan',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'Nama', value: order.customerName),
              InfoRow(label: 'Dibuat', value: formatDateTime(order.createdAt)),
              if (order.address.isNotEmpty) InfoRow(label: 'Kirim ke', value: order.address),
              if (order.courierName.isNotEmpty) InfoRow(label: 'Kurir', value: order.courierName),
              if (order.note.isNotEmpty) InfoRow(label: 'Catatan', value: order.note),
              if (order.cancelReason.isNotEmpty)
                InfoRow(label: 'Alasan batal', value: order.cancelReason, valueColor: tokens.danger),
            ],
          ),
        ),
        if (order.isCredit && order.status != OrderStatus.cancelled) _CreditInfo(order: order, role: user.role),
        SectionCard(
          title: 'Status pesanan',
          trailing: orderBadge(order.status),
          child: order.status == OrderStatus.cancelled
              ? Text('Pesanan ini dibatalkan.', style: text.bodySmall)
              : AppTimeline(steps: _steps(order.status), vertical: true),
        ),
        if (actions.isNotEmpty)
          SectionCard(
            title: 'Tindakan',
            child: Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, alignment: WrapAlignment.end, children: actions),
          ),
      ],
    );

    if (context.deviceClass == DeviceClass.phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [products, side]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.lg,
      children: [
        Expanded(flex: 3, child: products),
        SizedBox(width: 360, child: side),
      ],
    );
  }
}

/// Langkah pesanan: Menunggu → Diproses → Dibawa kurir → Terkirim → Diterima.
List<TimelineStep> _steps(OrderStatus status) {
  const sequence = [
    OrderStatus.pending,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.delivered,
    OrderStatus.done,
  ];
  final current = sequence.indexOf(status);
  return [
    for (var i = 0; i < sequence.length; i++)
      TimelineStep(
        label: sequence[i].label,
        state: i < current
            ? TimelineState.done
            : i == current
                ? TimelineState.active
                : TimelineState.upcoming,
      ),
  ];
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

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
                Text(lineDetail(line), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(formatRupiah(line.net), style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink)),
        ],
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

/// Pesanan tempo: barang tetap dikirim, pembayaran menyusul.
class _CreditInfo extends StatelessWidget {
  const _CreditInfo({required this.order, required this.role});

  final SalesOrder order;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final due = formatDate(order.creditDueDate!);
    final message = order.creditPaid
        ? 'Tempo s/d $due · sudah lunas'
        : switch (role) {
            UserRole.spv => 'Pembayaran TEMPO s/d $due. Barang tetap diantar, tidak perlu menagih saat antar.',
            UserRole.customer || UserRole.cafeOwner || UserRole.cashier =>
              'Pembayaran tempo: barang dikirim dulu, bayar paling lambat $due.',
            UserRole.owner => 'Pembayaran tempo s/d $due. Barang boleh dikirim sebelum lunas.',
          };
    final fg = order.creditPaid ? tokens.success : tokens.warning;
    final bg = order.creditPaid ? tokens.successTint : tokens.warningTint;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(order.creditPaid ? Icons.check_circle_outline : Icons.schedule, size: 18, color: fg),
          Expanded(
            child: Text(message, style: theme.textTheme.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
