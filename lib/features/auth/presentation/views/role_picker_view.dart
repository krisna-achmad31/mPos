import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../distributors/domain/distributor.dart';
import '../../auth_providers.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_view_model.dart';

/// Layar awal mode pilot: pilih distributor, lalu pilih role. Tanpa login
/// (padanan frame `63 · Mobile / Masuk`).
class RolePickerView extends ConsumerStatefulWidget {
  const RolePickerView({super.key});

  @override
  ConsumerState<RolePickerView> createState() => _RolePickerViewState();
}

class _RolePickerViewState extends ConsumerState<RolePickerView> {
  Distributor? _distributor;
  DateTime _stepChangedAt = DateTime(0);
  final _newName = TextEditingController();

  /// Kartu role muncul di posisi kartu distributor: abaikan tap yang "tembus" sesaat setelah pindah langkah.
  bool get _justSwitched => DateTime.now().difference(_stepChangedAt) < const Duration(milliseconds: 500);

  void _pickDistributor(Distributor? d) => setState(() {
        _distributor = d;
        _stepChangedAt = DateTime.now();
      });

  void _selectRole(Distributor d, UserRole role, {int customer = 1}) {
    if (_justSwitched) return;
    ref.read(authViewModelProvider.notifier).selectRole(d, role, customer: customer);
  }

  static const _descriptions = {
    UserRole.owner: 'Semua fitur: kasir, pesanan, produk, harga khusus, approval, laporan',
    UserRole.spv: 'Input stok masuk; perubahan perlu ACC Owner',
    UserRole.customer: 'Belanja dari katalog distributor ini, pantau pesanan dan invoice',
  };

  static const _icons = {
    UserRole.owner: Icons.admin_panel_settings_outlined,
    UserRole.spv: Icons.warehouse_outlined,
    UserRole.customer: Icons.storefront_outlined,
  };

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await ref.read(authViewModelProvider.notifier).createDistributor(_newName.text);
    if (created != null && mounted) {
      _newName.clear();
      _pickDistributor(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final busy = ref.watch(authViewModelProvider).isLoading;
    ref.listen(authViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    final distributor = _distributor;
    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.lg,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white, size: 26),
                  ),
                ),
                Column(
                  spacing: AppSpacing.xs,
                  children: [
                    Text('mPOS Distributor', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                    Text(
                      distributor == null
                          ? 'Mode pilot — langkah 1: pilih distributor'
                          : 'Langkah 2: pilih role',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
                if (distributor == null) ...[
                  AsyncValueView(
                    value: ref.watch(distributorsProvider),
                    data: (list) => Column(
                      spacing: AppSpacing.sm,
                      children: [
                        if (list.isEmpty)
                          Text(
                            'Belum ada distributor. Buat yang pertama di bawah.',
                            style: theme.textTheme.bodySmall,
                          ),
                        for (final d in list)
                          _PickTile(
                            icon: Icons.business_outlined,
                            title: d.name,
                            subtitle: 'Pilih untuk masuk',
                            onTap: () => _pickDistributor(d),
                          ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: 'Distributor baru',
                    subtitle: 'Buat distributor kosong lalu pilih role.',
                    child: Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newName,
                            decoration: const InputDecoration(labelText: 'Nama distributor'),
                            onSubmitted: (_) => _create(),
                          ),
                        ),
                        FilledButton(onPressed: busy ? null : _create, child: const Text('Buat')),
                      ],
                    ),
                  ),
                ] else ...[
                  _PickTile(
                    icon: Icons.business,
                    title: distributor.name,
                    subtitle: 'Distributor terpilih',
                    highlight: true,
                    badge: const StatusBadge('Terpilih', tone: BadgeTone.success, icon: Icons.check_circle_outline),
                    trailing: TextButton(
                      onPressed: () => _pickDistributor(null),
                      child: const Text('Ganti'),
                    ),
                  ),
                  for (final role in [UserRole.owner, UserRole.spv])
                    _PickTile(
                      icon: _icons[role]!,
                      title: role.label,
                      subtitle: _descriptions[role]!,
                      enabled: !busy,
                      onTap: () => _selectRole(distributor, role),
                    ),
                  SectionCard(
                    title: 'Customer',
                    subtitle: '${_descriptions[UserRole.customer]!}. '
                        'Dua akun uji untuk membandingkan harga khusus / promo.',
                    child: Column(
                      children: [
                        for (var i = 1; i <= DemoAuthRepository.demoCustomers.length; i++)
                          ListTile(
                            enabled: !busy,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(radius: 14, child: Text('$i')),
                            title: Text(DemoAuthRepository.demoCustomers[i - 1].store),
                            subtitle: Text(DemoAuthRepository.demoCustomers[i - 1].name),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => _selectRole(distributor, UserRole.customer, customer: i),
                          ),
                      ],
                    ),
                  ),
                  SectionCard(
                    title: 'POS Kopi (premium)',
                    subtitle: 'Kasir kedai kopi milik pelanggan di atas. Stok bahan bertambah otomatis dari pesanan '
                        'distributor yang diterima. Aktifkan dulu dengan kode promo dari Owner distributor.',
                    child: Column(
                      children: [
                        for (var i = 1; i <= DemoAuthRepository.demoCustomers.length; i++)
                          for (final role in [UserRole.cafeOwner, UserRole.cashier])
                            ListTile(
                              enabled: !busy,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(role == UserRole.cafeOwner ? Icons.storefront_outlined : Icons.point_of_sale, size: 22),
                              title: Text('${DemoAuthRepository.demoCustomers[i - 1].store} — ${role.label}'),
                              subtitle: Text(
                                role == UserRole.cafeOwner
                                    ? '${DemoAuthRepository.demoCustomers[i - 1].name}: menu, resep, stok, laporan'
                                    : '${DemoAuthRepository.demoCashier(distributor, i).name}: kasir & riwayat struk',
                              ),
                              trailing: const Icon(Icons.chevron_right, size: 20),
                              onTap: () => _selectRole(distributor, role, customer: i),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu pilih dengan ikon, judul, keterangan, dan lencana opsional.
class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? badge;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final primary = theme.colorScheme.primary;
    return Material(
      color: highlight ? tokens.primaryTint : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: enabled ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: highlight ? primary : tokens.line),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            spacing: AppSpacing.md,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: highlight ? theme.colorScheme.surface : tokens.primaryTint,
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                ),
                child: Icon(icon, size: 20, color: primary),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              ?badge,
              if (trailing != null)
                trailing!
              else if (onTap != null)
                Icon(Icons.chevron_right, size: 20, color: tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}
