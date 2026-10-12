import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_shell.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

/// Ditampilkan di semua halaman POS kopi saat premium tidak aktif. Data tetap tersimpan.
class CafeLockedView extends ConsumerWidget {
  const CafeLockedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentUserProvider).role == UserRole.cafeOwner;
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('POS Kopi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Icon(Icons.workspace_premium_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
              Text('Premium POS Kopi tidak aktif', style: Theme.of(context).textTheme.titleMedium),
              Text(
                owner
                    ? 'Data menu, stok, dan struk tetap aman. Aktifkan lagi dengan kode promo dari distributor.'
                    : 'Hubungi Owner untuk mengaktifkan kembali POS Kopi.',
                textAlign: TextAlign.center,
              ),
              if (owner)
                FilledButton.icon(
                  onPressed: () {
                    ref.read(authViewModelProvider.notifier).setCafeMode(false);
                    context.go('/shop/cafe');
                  },
                  icon: const Icon(Icons.redeem),
                  label: const Text('Masukkan kode promo'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
