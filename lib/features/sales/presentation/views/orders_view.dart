import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/sales_order.dart';
import '../../sales_providers.dart';
import '../widgets/sales_badges.dart';

/// Daftar pesanan online per status. Owner: semua; Customer: miliknya; SPV: pengiriman.
class OrdersView extends ConsumerWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwner = user.isOwner;
    final isCourier = user.role == UserRole.spv;
    final base = isOwner ? '/owner' : (isCourier ? '/spv' : '/shop');
    final tabs = isCourier
        ? const [OrderStatus.shipped, OrderStatus.delivered, OrderStatus.done]
        : OrderStatus.values;
    final title = isOwner ? 'Pesanan online' : (isCourier ? 'Pengiriman' : 'Pesanan saya');
    final subtitle = isOwner
        ? 'Kelola pesanan pelanggan tanpa kehilangan urutannya.'
        : isCourier
            ? 'Antar pesanan pelanggan dan tandai status pengirimannya.'
            : 'Pantau status pesanan yang sudah kamu buat.';

    return DefaultTabController(
      length: tabs.length,
      child: PageScaffold(
        title: title,
        subtitle: subtitle,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabs: [for (final s in tabs) Tab(text: s.label)],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: AsyncValueView(
                value: ref.watch(ordersProvider),
                data: (orders) => TabBarView(
                  children: [
                    for (final status in tabs)
                      _OrderList(
                        orders: orders.where((o) => o.status == status).toList(),
                        showCustomer: isOwner || isCourier,
                        onTap: (o) => context.go('$base/orders/${o.id}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nomor pesanan ringkas untuk ditampilkan di daftar/tabel.
String _orderRef(SalesOrder order) =>
    '#${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id.toUpperCase()}';

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.showCustomer, required this.onTap});

  final List<SalesOrder> orders;
  final bool showCustomer;
  final ValueChanged<SalesOrder> onTap;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Belum ada pesanan',
        message: 'Tidak ada pesanan pada status ini.',
      );
    }

    if (context.deviceClass == DeviceClass.phone) {
      return ListView.separated(
        itemCount: orders.length,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) => _OrderCard(
          order: orders[i],
          showCustomer: showCustomer,
          onTap: () => onTap(orders[i]),
        ),
      );
    }

    final columns = showCustomer
        ? const ['Pesanan', 'Pelanggan', 'Dibuat', 'Total', 'Status']
        : const ['Pesanan', 'Dibuat', 'Total', 'Status'];
    final flex = showCustomer ? const [2, 3, 2, 2, 2] : const [3, 2, 2, 2];

    return SingleChildScrollView(
      child: AppDataTable(
        columns: columns,
        flex: flex,
        onTap: (i) => onTap(orders[i]),
        emptyLabel: 'Tidak ada pesanan',
        rows: [
          for (final o in orders)
            [
              Text(_orderRef(o), style: const TextStyle(fontWeight: FontWeight.w600)),
              if (showCustomer)
                Text(
                  o.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              Text(formatDateTime(o.createdAt), style: Theme.of(context).textTheme.bodySmall),
              Text(formatRupiah(o.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
              Align(alignment: Alignment.centerLeft, child: orderBadge(o.status)),
            ],
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.showCustomer, required this.onTap});

  final SalesOrder order;
  final bool showCustomer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final itemCount = order.lines.fold<int>(0, (sum, l) => sum + l.qty);
    final meta = [
      if (showCustomer) order.customerName,
      formatDateTime(order.createdAt),
      '$itemCount item',
      if (showCustomer && order.address.isNotEmpty) order.address,
      if (order.courierName.isNotEmpty) 'Kurir: ${order.courierName}',
      if (order.isCredit && !order.creditPaid) 'Tempo s/d ${formatDate(order.creditDueDate!)}',
    ];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: Text(
                      _orderRef(order),
                      style: theme.textTheme.titleSmall?.copyWith(color: tokens.ink),
                    ),
                  ),
                  orderBadge(order.status),
                ],
              ),
              Text(
                meta.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    formatRupiah(order.subtotal),
                    style: theme.textTheme.titleMedium?.copyWith(color: tokens.ink),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: tokens.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
