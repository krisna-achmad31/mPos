import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_view_model.dart';

/// Layar awal mode demo: pilih role tanpa login.
class RolePickerView extends ConsumerWidget {
  const RolePickerView({super.key});

  static const _descriptions = {
    UserRole.owner: 'Semua fitur: kasir, pesanan, produk, harga khusus, approval, laporan',
    UserRole.spv: 'Input stok masuk; perubahan perlu ACC Owner',
    UserRole.customer: 'Belanja dari katalog, pantau pesanan dan invoice',
  };

  static const _icons = {
    UserRole.owner: Icons.admin_panel_settings_outlined,
    UserRole.spv: Icons.warehouse_outlined,
    UserRole.customer: Icons.storefront_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authViewModelProvider).isLoading;
    ref.listen(authViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Icon(Icons.storefront, size: 56, color: Theme.of(context).colorScheme.primary),
                Text('mPOS Distributor', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                const Text('Mode demo — pilih role untuk masuk', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                for (final role in UserRole.values)
                  Card(
                    child: ListTile(
                      enabled: !busy,
                      leading: Icon(_icons[role]),
                      title: Text(role.label),
                      subtitle: Text(_descriptions[role]!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ref.read(authViewModelProvider.notifier).selectRole(role),
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
