import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../distributors/domain/distributor.dart';
import '../../auth_providers.dart';
import '../../data/repositories/demo_auth_repository.dart';
import '../../domain/entities/user_role.dart';
import '../viewmodels/auth_view_model.dart';

/// Layar awal mode pilot: pilih distributor, lalu pilih role. Tanpa login.
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
    final busy = ref.watch(authViewModelProvider).isLoading;
    final text = Theme.of(context).textTheme;
    ref.listen(authViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    final distributor = _distributor;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Icon(Icons.storefront, size: 56, color: Theme.of(context).colorScheme.primary),
                Text('mPOS Distributor', textAlign: TextAlign.center, style: text.headlineSmall),
                Text(
                  distributor == null ? 'Mode pilot — langkah 1: pilih distributor' : 'Langkah 2: pilih role',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (distributor == null) ...[
                  AsyncValueView(
                    value: ref.watch(distributorsProvider),
                    data: (list) => Column(
                      spacing: 8,
                      children: [
                        if (list.isEmpty) const Text('Belum ada distributor. Buat yang pertama di bawah.'),
                        for (final d in list)
                          Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: CircleAvatar(child: Text(d.name.isEmpty ? '?' : d.name[0].toUpperCase())),
                              title: Text(d.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _pickDistributor(d),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 32),
                  Text('Distributor baru', style: text.titleSmall),
                  Row(
                    spacing: 8,
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
                ] else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.business),
                      title: Text(distributor.name),
                      subtitle: const Text('Distributor terpilih'),
                      trailing: TextButton(
                        onPressed: () => _pickDistributor(null),
                        child: const Text('Ganti'),
                      ),
                    ),
                  ),
                  for (final role in [UserRole.owner, UserRole.spv])
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        enabled: !busy,
                        leading: Icon(_icons[role]),
                        title: Text(role.label),
                        subtitle: Text(_descriptions[role]!),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _selectRole(distributor, role),
                      ),
                    ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(_icons[UserRole.customer]),
                          title: const Text('Customer'),
                          subtitle: Text('${_descriptions[UserRole.customer]!}. '
                              'Dua akun uji untuk membandingkan harga khusus / promo.'),
                        ),
                        for (var i = 1; i <= DemoAuthRepository.demoCustomers.length; i++)
                          ListTile(
                            enabled: !busy,
                            contentPadding: const EdgeInsets.only(left: 72, right: 16),
                            leading: CircleAvatar(radius: 14, child: Text('$i')),
                            title: Text(DemoAuthRepository.demoCustomers[i - 1].store),
                            subtitle: Text(DemoAuthRepository.demoCustomers[i - 1].name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _selectRole(distributor, UserRole.customer, customer: i),
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
