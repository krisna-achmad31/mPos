import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/cafe/cafe_providers.dart';
import '../../features/cafe/presentation/views/cafe_locked_view.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../config/app_config.dart';
import '../theme/app_tokens.dart';
import '../widgets/appearance_picker.dart';

class NavItem {
  const NavItem(this.label, this.icon, this.path);

  final String label;
  final IconData icon;
  final String path;
}

/// Kelompok menu di sidebar web (padanan judul bagian di `design_ui.pen`).
class NavSection {
  const NavSection(this.title, this.items);

  final String title;
  final List<NavItem> items;
}

const ownerNavSections = [
  NavSection('Utama', [
    NavItem('Dashboard', Icons.dashboard_outlined, '/owner'),
    NavItem('Kasir', Icons.point_of_sale, '/owner/pos'),
    NavItem('Pesanan online', Icons.inbox_outlined, '/owner/orders'),
    NavItem('Riwayat nota', Icons.receipt_long_outlined, '/owner/invoices'),
  ]),
  NavSection('Katalog & stok', [
    NavItem('Produk', Icons.inventory_2_outlined, '/owner/products'),
    NavItem('Stok masuk', Icons.move_to_inbox_outlined, '/owner/stock-in'),
  ]),
  NavSection('Operasional', [
    NavItem('Approval', Icons.fact_check_outlined, '/owner/approvals'),
    NavItem('Harga khusus & promo', Icons.local_offer_outlined, '/owner/discounts'),
    NavItem('Pengeluaran', Icons.payments_outlined, '/owner/expenses'),
    NavItem('Laporan', Icons.bar_chart, '/owner/reports'),
  ]),
  NavSection('Lainnya', [
    NavItem('Pengguna', Icons.group_outlined, '/owner/users'),
    NavItem('Premium POS Kopi', Icons.workspace_premium_outlined, '/owner/premium'),
    NavItem('Pengaturan', Icons.settings_outlined, '/owner/settings'),
  ]),
];

const spvNavSections = [
  NavSection('Operasional', [
    NavItem('Stok masuk', Icons.move_to_inbox_outlined, '/spv'),
    NavItem('Pengiriman', Icons.local_shipping_outlined, '/spv/deliveries'),
    NavItem('Pengajuan saya', Icons.fact_check_outlined, '/spv/requests'),
  ]),
];

const customerNavSections = [
  NavSection('Belanja distributor', [
    NavItem('Katalog', Icons.storefront_outlined, '/shop'),
    NavItem('Keranjang', Icons.shopping_cart_outlined, '/shop/cart'),
    NavItem('Pesanan saya', Icons.inbox_outlined, '/shop/orders'),
    NavItem('Nota saya', Icons.receipt_long_outlined, '/shop/invoices'),
  ]),
  NavSection('Akun', [
    NavItem('Belanja saya', Icons.insights_outlined, '/shop/spending'),
    NavItem('POS Kopi', Icons.coffee_maker_outlined, '/shop/cafe'),
  ]),
];

const cafeOwnerNavSections = [
  NavSection('POS Kopi', [
    NavItem('Dashboard', Icons.dashboard_outlined, '/cafe'),
    NavItem('Kasir', Icons.point_of_sale, '/cafe/pos'),
    NavItem('Riwayat struk', Icons.receipt_long_outlined, '/cafe/receipts'),
    NavItem('Menu & resep', Icons.menu_book_outlined, '/cafe/menu'),
  ]),
  NavSection('Operasional', [
    NavItem('Stok bahan', Icons.inventory_2_outlined, '/cafe/stock'),
    NavItem('Pengeluaran', Icons.payments_outlined, '/cafe/expenses'),
    NavItem('Laporan', Icons.bar_chart, '/cafe/reports'),
    NavItem('Pengaturan & printer', Icons.settings_outlined, '/cafe/settings'),
  ]),
];

const cashierNavSections = [
  NavSection('POS Kopi', [
    NavItem('Kasir', Icons.point_of_sale, '/cafe/pos'),
    NavItem('Riwayat struk', Icons.receipt_long_outlined, '/cafe/receipts'),
  ]),
];

List<NavSection> sectionsFor(UserRole role) => switch (role) {
  UserRole.owner => ownerNavSections,
  UserRole.spv => spvNavSections,
  UserRole.customer => customerNavSections,
  UserRole.cafeOwner => cafeOwnerNavSections,
  UserRole.cashier => cashierNavSections,
};

List<NavItem> navFor(UserRole role) => [
  for (final section in sectionsFor(role)) ...section.items,
];

/// Indeks menu sidebar/rail yang sedang dibuka untuk [location], atau `-1`
/// bila tidak ada yang cocok (mis. halaman detail).
///
/// Sengaja tidak kembali ke menu terakhir: alamat bisa belum sinkron sesaat
/// setelah redirect (`/splash` -> `/owner`), dan menu yang salah sorot lebih
/// membingungkan daripada tidak ada yang tersorot.
int sidebarIndexFor(List<NavItem> items, String location) {
  var best = -1;
  for (var i = 0; i < items.length; i++) {
    final p = items[i].path;
    if (p == shellAccountPath) continue;
    if (location == p || location.startsWith('$p/')) {
      if (best == -1 || p.length > items[best].path.length) best = i;
    }
  }
  return best;
}

/// Menu utama di bilah navigasi bawah (HP) — sisanya masuk tab `Akun`.
List<NavItem> primaryTabsFor(UserRole role) => switch (role) {
  UserRole.owner => const [
    NavItem('Dashboard', Icons.dashboard_outlined, '/owner'),
    NavItem('Kasir', Icons.point_of_sale, '/owner/pos'),
    NavItem('Pesanan', Icons.inbox_outlined, '/owner/orders'),
    NavItem('Akun', Icons.person_outline, '/akun'),
  ],
  UserRole.spv => const [
    NavItem('Stok masuk', Icons.move_to_inbox_outlined, '/spv'),
    NavItem('Pengiriman', Icons.local_shipping_outlined, '/spv/deliveries'),
    NavItem('Pengajuan', Icons.fact_check_outlined, '/spv/requests'),
    NavItem('Akun', Icons.person_outline, '/akun'),
  ],
  UserRole.customer => const [
    NavItem('Katalog', Icons.storefront_outlined, '/shop'),
    NavItem('Pesanan', Icons.inbox_outlined, '/shop/orders'),
    NavItem('Nota', Icons.receipt_long_outlined, '/shop/invoices'),
    NavItem('Akun', Icons.person_outline, '/akun'),
  ],
  UserRole.cafeOwner => const [
    NavItem('Dashboard', Icons.dashboard_outlined, '/cafe'),
    NavItem('Kasir', Icons.point_of_sale, '/cafe/pos'),
    NavItem('Struk', Icons.receipt_long_outlined, '/cafe/receipts'),
    NavItem('Akun', Icons.person_outline, '/akun'),
  ],
  UserRole.cashier => const [
    NavItem('Kasir', Icons.point_of_sale, '/cafe/pos'),
    NavItem('Riwayat struk', Icons.receipt_long_outlined, '/cafe/receipts'),
  ],
};

/// Penanda tab `Akun` pada bilah navigasi bawah.
const shellAccountPath = '/akun';

/// Tombol menu pada app bar. Di layar web (>= 1000) menu sudah permanen di
/// sisi kiri sehingga tidak perlu tombol.
///
/// Di HP & tablet tombol ini membuka daftar menu lengkap (termasuk akun),
/// karena bilah bawah / rel ikon tidak memuat semua tujuan.
Widget? shellMenuButton(BuildContext context) {
  if (MediaQuery.sizeOf(context).width >= Breakpoints.desktop) return null;
  return IconButton(
    icon: const Icon(Icons.menu),
    tooltip: 'Menu',
    onPressed: () => showShellMenu(context),
  );
}

/// Daftar menu lengkap + akun dalam bentuk bottom sheet.
Future<void> showShellMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ShellMenuSheet(),
  );
}

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sections = sectionsFor(user.role);
    final items = navFor(user.role);
    final device = context.deviceClass;
    // `location` datang dari ShellRoute (`state.uri.path`) sehingga selalu sama
    // dengan halaman yang sedang tampil — termasuk sesaat setelah redirect
    // (mis. `/splash` -> `/owner`), saat URL di peramban belum diperbarui.
    final path = location;
    final selected = sidebarIndexFor(items, path);
    // POS kopi tanpa premium aktif: semua halaman diganti layar terkunci (data tetap tersimpan).
    final body = user.role.isCafe && !ref.watch(cafePremiumProvider) ? const CafeLockedView() : child;

    return switch (device) {
      DeviceClass.desktop => Row(
        children: [
          SizedBox(
            width: Breakpoints.sidebarWidth,
            child: _ShellSidebar(
              sections: sections,
              selected: selected,
              onSelect: (item) => context.go(item.path),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
      DeviceClass.tablet => Row(
        children: [
          SizedBox(
            width: Breakpoints.railWidth,
            child: _ShellRail(
              items: items,
              selected: selected,
              onSelect: (item) => context.go(item.path),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
      DeviceClass.phone => Scaffold(
        body: body,
        bottomNavigationBar: _ShellBottomBar(
          path: path,
          onSelect: (item) => context.go(item.path),
        ),
      ),
    };
  }
}

/// Inisial nama untuk avatar bulat.
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Sidebar web 224 px: merek, daftar menu per bagian, lalu blok akun.
class _ShellSidebar extends ConsumerWidget {
  const _ShellSidebar({required this.sections, required this.selected, required this.onSelect});

  final List<NavSection> sections;
  final int selected;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final distributor = ref.watch(currentDistributorProvider).value?.name;
    final subtitle = user.role.isCafe
        ? '${user.role.label}${user.role == UserRole.cashier ? ' ${user.name}' : ''} · POS Kopi'
        : '${user.role.label}${distributor == null ? '' : ' · $distributor'}';

    var index = 0;
    final rows = <Widget>[];
    for (final section in sections) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
          child: Text(
            section.title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, letterSpacing: 0.6),
          ),
        ),
      );
      for (final item in section.items) {
        final isSelected = index == selected;
        rows.add(_SidebarItem(
          item: item,
          selected: isSelected,
          onTap: () => onSelect(item),
        ));
        index++;
      }
    }

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandTile(subtitle: null),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              children: rows,
            ),
          ),
          Divider(height: 1, color: tokens.line),
          const _AccountFooter(),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final primary = Theme.of(context).colorScheme.primary;
    final color = selected ? primary : tokens.ink;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? tokens.primaryTint : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              spacing: 10,
              children: [
                Icon(item.icon, size: 18, color: selected ? primary : tokens.muted),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rel ikon 76 px untuk tablet.
class _ShellRail extends ConsumerWidget {
  const _ShellRail({required this.items, required this.selected, required this.onSelect});

  final List<NavItem> items;
  final int selected;
  final ValueChanged<NavItem> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final primary = theme.colorScheme.primary;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          const _BrandTile(subtitle: null, compact: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Tooltip(
                      message: items[i].label,
                      child: Material(
                        color: i == selected ? tokens.primaryTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          onTap: () => onSelect(items[i]),
                          child: SizedBox(
                            height: 44,
                            child: Icon(
                              items[i].icon,
                              size: 20,
                              color: i == selected ? primary : tokens.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          const _AccountFooter(compact: true),
        ],
      ),
    );
  }
}

class _BrandTile extends ConsumerWidget {
  const _BrandTile({this.subtitle, this.compact = false});

  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final tile = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(AppRadius.tile)),
      alignment: Alignment.center,
      child: const Text(
        'm',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, height: 1),
      ),
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: tile,
      );
    }

    final isCafe = user.role.isCafe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
      child: Row(
        spacing: 10,
        children: [
          tile,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('mPos', style: theme.textTheme.titleMedium),
                Text(
                  isCafe ? 'POS Kopi' : 'Distributor',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Blok akun di bawah sidebar/rail: avatar, nama, dan tombol keluar.
class _AccountFooter extends ConsumerWidget {
  const _AccountFooter({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final primary = theme.colorScheme.primary;

    final avatar = CircleAvatar(
      radius: 15,
      backgroundColor: tokens.primaryTint,
      child: Text(
        _initials(user.displayName),
        style: theme.textTheme.labelSmall?.copyWith(color: primary, fontWeight: FontWeight.w700),
      ),
    );

    if (compact) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Tooltip(message: user.displayName, child: avatar),
          ),
          const AppearanceMenuButton(),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Tooltip(
              message: AppConfig.demoMode ? 'Ganti role' : 'Keluar',
              child: IconButton(
                icon: Icon(AppConfig.demoMode ? Icons.swap_horiz : Icons.logout, size: 20),
                onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
              ),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      child: Row(
        spacing: 10,
        children: [
          avatar,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  user.role.label,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          const AppearanceMenuButton(),
          IconButton(
            tooltip: AppConfig.demoMode ? 'Ganti role' : 'Keluar',
            icon: Icon(AppConfig.demoMode ? Icons.swap_horiz : Icons.logout, size: 18),
            onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }
}

/// Bilah navigasi bawah untuk HP: menu utama + tab `Akun`.
class _ShellBottomBar extends ConsumerWidget {
  const _ShellBottomBar({required this.path, required this.onSelect});

  final String path;
  final ValueChanged<NavItem> onSelect;

  int _index(List<NavItem> tabs) {
    var best = -1;
    for (var i = 0; i < tabs.length; i++) {
      final p = tabs[i].path;
      if (p == shellAccountPath) continue;
      if (path == p || path.startsWith('$p/')) {
        if (best == -1 || p.length > tabs[best].path.length) best = i;
      }
    }
    return best == -1 ? tabs.length - 1 : best;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = primaryTabsFor(ref.watch(currentUserProvider).role);
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: tokens.line)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index(tabs),
          onDestinationSelected: (i) {
            final tab = tabs[i];
            if (tab.path == shellAccountPath) {
              showShellMenu(context);
            } else {
              onSelect(tab);
            }
          },
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                label: tab.label,
                tooltip: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet berisi seluruh menu + blok akun.
class _ShellMenuSheet extends ConsumerWidget {
  const _ShellMenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final sections = sectionsFor(user.role);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final router = GoRouter.of(context);

    void close() => Navigator.of(context).maybePop();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                spacing: 10,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: tokens.primaryTint,
                    child: Text(
                      _initials(user.displayName),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: theme.textTheme.titleSmall),
                        Text(user.role.label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final section in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Text(
                  section.title.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, letterSpacing: 0.6),
                ),
              ),
              for (final item in section.items)
                ListTile(
                  dense: true,
                  leading: Icon(item.icon, size: 20),
                  title: Text(item.label),
                  onTap: () {
                    close();
                    router.go(item.path);
                  },
                ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: Text(
                'TAMPILAN',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, letterSpacing: 0.6),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: AppearancePicker(),
            ),
            if (user.role == UserRole.cafeOwner)
              ListTile(
                dense: true,
                leading: const Icon(Icons.storefront_outlined, size: 20),
                title: const Text('Belanja ke distributor'),
                onTap: () {
                  close();
                  // Owner Kopi = akun Customer yang sama: kembali berbelanja ke distributor.
                  ref.read(authViewModelProvider.notifier).setCafeMode(false);
                },
              ),
            const Divider(height: 20),
            ListTile(
              dense: true,
              leading: Icon(AppConfig.demoMode ? Icons.swap_horiz : Icons.logout, size: 20),
              title: Text(AppConfig.demoMode ? 'Ganti role' : 'Keluar'),
              onTap: () {
                close();
                ref.read(authViewModelProvider.notifier).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

