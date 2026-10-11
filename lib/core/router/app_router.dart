import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../config/app_config.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/domain/entities/user_role.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/auth/presentation/views/register_view.dart';
import '../../features/auth/presentation/views/role_picker_view.dart';
import '../../features/auth/presentation/views/users_view.dart';
import '../../features/catalog/presentation/views/cart_view.dart';
import '../../features/catalog/presentation/views/catalog_view.dart';
import '../../features/dashboard/dashboard_view.dart';
import '../../features/expenses/presentation/expenses_view.dart';
import '../../features/pricing/presentation/views/discounts_view.dart';
import '../../features/products/presentation/views/product_form_view.dart';
import '../../features/products/presentation/views/product_list_view.dart';
import '../../features/reports/presentation/views/reports_view.dart';
import '../../features/sales/presentation/views/invoice_view.dart';
import '../../features/sales/presentation/views/invoices_view.dart';
import '../../features/sales/presentation/views/order_detail_view.dart';
import '../../features/sales/presentation/views/orders_view.dart';
import '../../features/sales/presentation/views/pos_view.dart';
import '../../features/settings/presentation/settings_view.dart';
import '../../features/stock/presentation/views/change_requests_view.dart';
import '../../features/stock/presentation/views/stock_in_view.dart';
import 'app_shell.dart';

String homeFor(UserRole role) => switch (role) {
      UserRole.owner => '/owner',
      UserRole.spv => '/spv',
      UserRole.customer => '/shop',
    };

/// Area URL yang boleh dibuka tiap role.
bool canAccess(UserRole role, String location) => switch (role) {
      UserRole.owner => location.startsWith('/owner'),
      UserRole.spv => location.startsWith('/spv'),
      UserRole.customer => location.startsWith('/shop'),
    };

/// Keputusan redirect murni, terpisah dari GoRouter agar mudah dites.
String? resolveRedirect(AsyncValue<AppUser?> auth, String location) {
  const publicPages = {'/login', '/register'};
  if (auth.isLoading && !auth.hasValue) return location == '/splash' ? null : '/splash';

  final user = auth.value;
  if (user == null) return publicPages.contains(location) ? null : '/login';
  if (!user.active) return location == '/inactive' ? null : '/inactive';

  final home = homeFor(user.role);
  if (publicPages.contains(location) || location == '/splash' || location == '/inactive') return home;
  return canAccess(user.role, location) ? null : home;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AsyncValue<AppUser?>>(const AsyncLoading());
  ref.listen(authStateProvider, (_, next) => auth.value = next, fireImmediately: true);
  ref.onDispose(auth.dispose);

  ShellRoute shell(List<RouteBase> routes) => ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: routes,
      );

  GoRoute page(String path, Widget Function(GoRouterState state) build) =>
      GoRoute(path: path, pageBuilder: (context, state) => NoTransitionPage(child: build(state)));

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => resolveRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator()))),
      GoRoute(
        path: '/login',
        builder: (_, _) => AppConfig.demoMode ? const RolePickerView() : const LoginView(),
      ),
      GoRoute(path: '/register', builder: (_, _) => const RegisterView()),
      GoRoute(path: '/inactive', builder: (_, _) => const _InactiveView()),
      shell([
        page('/owner', (_) => const DashboardView()),
        page('/owner/pos', (_) => const PosView()),
        page('/owner/orders', (_) => const OrdersView()),
        page('/owner/orders/:id', (s) => OrderDetailView(orderId: s.pathParameters['id']!)),
        page('/owner/invoices', (_) => const InvoicesView()),
        page('/owner/invoices/:id', (s) => InvoiceView(invoiceId: s.pathParameters['id']!)),
        page('/owner/products', (_) => const ProductListView()),
        page('/owner/products/new', (_) => const ProductFormView()),
        page('/owner/products/:id', (s) => ProductFormView(productId: s.pathParameters['id'])),
        page('/owner/stock-in', (_) => const StockInView()),
        page('/owner/approvals', (_) => const ChangeRequestsView()),
        page('/owner/discounts', (_) => const DiscountsView()),
        page('/owner/expenses', (_) => const ExpensesView()),
        page('/owner/reports', (_) => const ReportsView()),
        page('/owner/users', (_) => const UsersView()),
        page('/owner/settings', (_) => const SettingsView()),
      ]),
      shell([
        page('/spv', (_) => const StockInView()),
        page('/spv/requests', (_) => const ChangeRequestsView()),
      ]),
      shell([
        page('/shop', (_) => const CatalogView()),
        page('/shop/cart', (_) => const CartView()),
        page('/shop/orders', (_) => const OrdersView()),
        page('/shop/orders/:id', (s) => OrderDetailView(orderId: s.pathParameters['id']!)),
        page('/shop/invoices', (_) => const InvoicesView()),
        page('/shop/invoices/:id', (s) => InvoiceView(invoiceId: s.pathParameters['id']!)),
      ]),
    ],
  );
});

class _InactiveView extends ConsumerWidget {
  const _InactiveView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const Text('Akun Anda belum aktif atau dinonaktifkan. Hubungi Owner.', textAlign: TextAlign.center),
              OutlinedButton(
                onPressed: () => ref.read(authViewModelProvider.notifier).signOut(),
                child: const Text('Keluar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
