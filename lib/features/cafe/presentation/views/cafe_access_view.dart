import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/app_timeline.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../cafe_providers.dart';
import '../cafe_view_models.dart';

/// Customer: status premium POS kopi, pakai kode promo dari distributor, dan buka POS kopi
/// (padanan frame `39 · Pelanggan / Akses POS Kopi`, `76 · Mobile`, `90 · Tablet`).
class CafeAccessView extends ConsumerStatefulWidget {
  const CafeAccessView({super.key});

  @override
  ConsumerState<CafeAccessView> createState() => _CafeAccessViewState();
}

class _CafeAccessViewState extends ConsumerState<CafeAccessView> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final vm = ref.read(cafeActionsViewModelProvider.notifier);
    final ok = await vm.redeem(_code.text);
    if (!mounted) return;
    if (ok) {
      _code.clear();
      showMessage(context, 'Premium POS Kopi aktif. Selamat berjualan!');
    } else {
      showMessage(context, '${ref.read(cafeActionsViewModelProvider).error}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final cafe = ref.watch(myCafeProvider);
    final premium = ref.watch(cafePremiumProvider) && cafe.hasValue;
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final until = cafe.value?.premiumUntil;

    return PageScaffold(
      title: 'Akses POS Kopi',
      subtitle: 'Kelola menu, resep, kasir, dan stok bahan untuk kedai Anda.',
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Status akses',
            subtitle: premium ? 'Premium POS Kopi aktif.' : 'Premium belum aktif.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: [
                Row(
                  spacing: AppSpacing.md,
                  children: [
                    Icon(Icons.coffee_maker_outlined, size: 36, color: theme.colorScheme.primary),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.xs,
                        children: [
                          Text(user.displayName, style: text.titleMedium),
                          Text(
                            premium
                                ? 'Premium aktif sampai ${formatDate(until!)}'
                                : until != null
                                    ? 'Premium berakhir ${formatDate(until)}'
                                    : 'Fitur premium belum aktif',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(
                      premium ? 'Premium' : 'Tidak aktif',
                      tone: premium ? BadgeTone.success : BadgeTone.neutral,
                      icon: premium ? Icons.verified : Icons.lock_outline,
                    ),
                  ],
                ),
                if (premium)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () => ref.read(authViewModelProvider.notifier).setCafeMode(true),
                      icon: const Icon(Icons.point_of_sale, size: 18),
                      label: const Text('Buka POS Kopi'),
                    ),
                  ),
              ],
            ),
          ),
          SectionCard(
            title: premium ? 'Perpanjang dengan kode premium' : 'Aktifkan dengan kode premium',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Text(
                  'Minta kode premium ke distributor Anda (${ref.watch(currentDistributorProvider).value?.name ?? '…'}). '
                  'Masa premium bertambah sesuai kode, dihitung dari tanggal berakhir bila masih aktif.',
                  style: text.bodySmall,
                ),
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Kode premium', hintText: 'mis. KOPI30'),
                        onSubmitted: (_) => _redeem(),
                      ),
                    ),
                    FilledButton(
                      onPressed: busy ? null : _redeem,
                      child: Text(premium ? 'Perpanjang' : 'Aktifkan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Yang Anda dapat',
            subtitle: 'Fitur yang aktif bersama premium.',
            child: AppTimeline(
              steps: [
                for (final (icon, label, caption) in _benefits)
                  TimelineStep(label: label, caption: caption, icon: icon, state: TimelineState.done),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fitur yang aktif bersama premium POS Kopi.
const _benefits = <(IconData, String, String)>[
  (
    Icons.sync_alt,
    'Stok otomatis',
    'Belanja di distributor langsung menambah stok bahan saat Anda konfirmasi barang diterima.',
  ),
  (
    Icons.menu_book_outlined,
    'Menu & resep',
    'Setiap menu terjual memotong stok bahan sesuai takaran resep (gram, ml, pcs).',
  ),
  (Icons.print_outlined, 'Struk thermal', 'Cetak struk ke printer Bluetooth 58/80 mm.'),
  (Icons.badge_outlined, 'Owner & Kasir', 'Kasir hanya bisa berjualan dan melihat struk.'),
  (
    Icons.bar_chart,
    'Laporan',
    'Omzet, menu terlaris, jam ramai, laba setelah HPP bahan & pengeluaran.',
  ),
];
