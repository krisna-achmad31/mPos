import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../cafe_providers.dart';
import '../cafe_view_models.dart';

/// Customer: status premium POS kopi, pakai kode promo dari distributor, dan buka POS kopi.
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
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final until = cafe.value?.premiumUntil;

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('POS Kopi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Card(
                    color: premium ? scheme.primaryContainer : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          Row(
                            spacing: 12,
                            children: [
                              Icon(Icons.coffee_maker_outlined, size: 36, color: scheme.primary),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(user.displayName, style: text.titleMedium),
                                    Text(
                                      premium
                                          ? 'Premium aktif sampai ${formatDate(until!)}'
                                          : until != null
                                              ? 'Premium berakhir ${formatDate(until)}'
                                              : 'Fitur premium',
                                      style: text.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (premium)
                            FilledButton.icon(
                              onPressed: () => ref.read(authViewModelProvider.notifier).setCafeMode(true),
                              icon: const Icon(Icons.point_of_sale),
                              label: const Text('Buka POS Kopi'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const _Benefits(),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 12,
                        children: [
                          Text(premium ? 'Perpanjang dengan kode promo' : 'Aktifkan dengan kode promo', style: text.titleSmall),
                          Text(
                            'Minta kode promo ke distributor Anda (${ref.watch(currentDistributorProvider).value?.name ?? '…'}). '
                            'Masa premium bertambah sesuai kode, dihitung dari tanggal berakhir bila masih aktif.',
                            style: text.bodySmall,
                          ),
                          Row(
                            spacing: 8,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _code,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(labelText: 'Kode promo', hintText: 'mis. KOPI30'),
                                  onSubmitted: (_) => _redeem(),
                                ),
                              ),
                              FilledButton(onPressed: busy ? null : _redeem, child: const Text('Pakai')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  static const _items = [
    (Icons.sync_alt, 'Stok otomatis', 'Belanja di distributor langsung menambah stok bahan saat Anda konfirmasi barang diterima.'),
    (Icons.menu_book_outlined, 'Menu & resep', 'Setiap menu terjual memotong stok bahan sesuai takaran resep (gram, ml, pcs).'),
    (Icons.print_outlined, 'Struk thermal', 'Cetak struk ke printer Bluetooth 58/80 mm.'),
    (Icons.badge_outlined, 'Owner & Kasir', 'Kasir hanya bisa berjualan dan melihat struk.'),
    (Icons.bar_chart, 'Laporan', 'Omzet, menu terlaris, jam ramai, laba setelah HPP bahan & pengeluaran.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (final (icon, title, subtitle) in _items)
            ListTile(leading: Icon(icon), title: Text(title), subtitle: Text(subtitle)),
        ],
      ),
    );
  }
}
