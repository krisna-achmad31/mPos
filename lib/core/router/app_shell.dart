import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../config/app_config.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

const ownerNav = [
  NavItem('Dashboard', Icons.dashboard_outlined, '/owner'),
  NavItem('Kasir', Icons.point_of_sale, '/owner/pos'),
  NavItem('Pesanan online', Icons.inbox_outlined, '/owner/orders'),
  NavItem('Riwayat nota', Icons.receipt_long_outlined, '/owner/invoices'),
  NavItem('Produk', Icons.inventory_2_outlined, '/owner/products'),
  NavItem('Stok masuk', Icons.move_to_inbox_outlined, '/owner/stock-in'),
  NavItem('Approval', Icons.fact_check_outlined, '/owner/approvals'),
  NavItem('Harga khusus & promo', Icons.local_offer_outlined, '/owner/discounts'),
  NavItem('Pengeluaran', Icons.payments_outlined, '/owner/expenses'),
  NavItem('Laporan', Icons.bar_chart, '/owner/reports'),
  NavItem('Pengguna', Icons.group_outlined, '/owner/users'),
  NavItem('Pengaturan', Icons.settings_outlined, '/owner/settings'),
];

const spvNav = [
  NavItem('Stok masuk', Icons.move_to_inbox_outlined, '/spv'),
  NavItem('Pengajuan saya', Icons.fact_check_outlined, '/spv/requests'),
];

const customerNav = [
  NavItem('Katalog', Icons.storefront_outlined, '/shop'),
  NavItem('Keranjang', Icons.shopping_cart_outlined, '/shop/cart'),
  NavItem('Pesanan saya', Icons.inbox_outlined, '/shop/orders'),
  NavItem('Nota saya', Icons.receipt_long_outlined, '/shop/invoices'),
];

final shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Tombol menu untuk AppBar halaman utama; null di layar lebar (menu sudah permanen).
Widget? shellMenuButton(BuildContext context) => MediaQuery.sizeOf(context).width >= 1000
    ? null
    : IconButton(icon: const Icon(Icons.menu), onPressed: () => shellScaffoldKey.currentState?.openDrawer());

List<NavItem> navFor(UserRole role) => switch (role) {
      UserRole.owner => ownerNav,
      UserRole.spv => spvNav,
      UserRole.customer => customerNav,
    };

/// Kerangka navigasi: menu samping permanen di layar lebar, drawer di HP.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int _selected(List<NavItem> items) {
    var best = 0;
    for (var i = 0; i < items.length; i++) {
      final p = items[i].path;
      if ((location == p || location.startsWith('$p/')) && p.length >= items[best].path.length) best = i;
    }
    return best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final items = navFor(user.role);
    final selected = _selected(items);
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final drawer = NavigationDrawer(
      selectedIndex: selected,
      onDestinationSelected: (i) {
        if (!wide) shellScaffoldKey.currentState?.closeDrawer();
        context.go(items[i].path);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 16, 4),
          child: Text(user.displayName, style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 16, 12),
          child: Text(user.role.label, style: Theme.of(context).textTheme.bodySmall),
        ),
        for (final item in items) NavigationDrawerDestination(icon: Icon(item.icon), label: Text(item.label)),
        const Divider(indent: 28, endIndent: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ListTile(
            leading: Icon(AppConfig.demoMode ? Icons.swap_horiz : Icons.logout),
            title: Text(AppConfig.demoMode ? 'Ganti role' : 'Keluar'),
            onTap: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),
        ),
      ],
    );

    if (wide) {
      return Row(children: [SizedBox(width: 280, child: drawer), const VerticalDivider(width: 1), Expanded(child: child)]);
    }
    return Scaffold(key: shellScaffoldKey, drawer: drawer, body: child);
  }
}
