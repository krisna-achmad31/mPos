import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

/// Ditampilkan di semua halaman POS kopi saat premium tidak aktif. Data tetap tersimpan.
class CafeLockedView extends ConsumerWidget {
  const CafeLockedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(currentUserProvider).role == UserRole.cafeOwner;
    return PageScaffold(
      title: 'POS Kopi',
      subtitle: 'Mode kasir kopi terkunci.',
      workspace: 'POS Kopi',
      scrollable: false,
      child: EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Premium POS Kopi tidak aktif',
        message: owner
            ? 'Data menu, stok, dan struk tetap aman. Aktifkan lagi dengan kode promo dari distributor.'
            : 'Hubungi Owner untuk mengaktifkan kembali POS Kopi.',
        action: owner
            ? FilledButton.icon(
                onPressed: () {
                  ref.read(authViewModelProvider.notifier).setCafeMode(false);
                  context.go('/shop/cafe');
                },
                icon: const Icon(Icons.redeem),
                label: const Text('Aktifkan premium'),
              )
            : null,
      ),
    );
  }
}
