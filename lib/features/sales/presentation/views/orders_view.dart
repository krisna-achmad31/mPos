import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../domain/entities/sales_order.dart';
import '../../sales_providers.dart';
import '../../../../core/router/app_shell.dart';

/// Daftar pesanan online per status. Owner: semua; Customer: miliknya.
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

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(leading: shellMenuButton(context), 
          title: Text(isOwner ? 'Pesanan Online' : (isCourier ? 'Pengiriman Saya' : 'Pesanan Saya')),
          bottom: TabBar(isScrollable: true, tabs: [for (final s in tabs) Tab(text: s.label)]),
        ),
        body: AsyncValueView(
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
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders, required this.showCustomer, required this.onTap});

  final List<SalesOrder> orders;
  final bool showCustomer;
  final ValueChanged<SalesOrder> onTap;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, message: 'Tidak ada pesanan');
    return ListView.separated(
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final o = orders[i];
        return ListTile(
          title: Text(showCustomer ? o.customerName : '${o.lines.length} barang'),
          subtitle: Text([
            '${formatDateTime(o.createdAt)} · ${o.lines.fold(0, (s, l) => s + l.qty)} item',
            if (showCustomer && o.address.isNotEmpty) o.address,
            if (o.courierName.isNotEmpty) 'Kurir: ${o.courierName}',
          ].join('\n')),
          trailing: Text(formatRupiah(o.subtotal)),
          onTap: () => onTap(o),
        );
      },
    );
  }
}
