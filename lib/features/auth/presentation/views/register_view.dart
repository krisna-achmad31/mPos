import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/feedback.dart';
import '../../auth_providers.dart';
import '../viewmodels/auth_view_model.dart';

/// Pendaftaran: distributor baru (menjadi Owner) atau pelanggan sebuah distributor.
class RegisterView extends ConsumerStatefulWidget {
  const RegisterView({super.key});

  @override
  ConsumerState<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<RegisterView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _asDistributor = true;
  String? _distributorId;

  @override
  void dispose() {
    for (final c in [_name, _business, _phone, _address, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = ref.read(authViewModelProvider.notifier);
    if (_asDistributor) {
      await vm.registerDistributor(
        ownerName: _name.text,
        distributorName: _business.text,
        phone: _phone.text,
        email: _email.text,
        password: _password.text,
      );
    } else {
      await vm.register(
        distributorId: _distributorId ?? '',
        name: _name.text,
        storeName: _business.text,
        phone: _phone.text,
        address: _address.text,
        email: _email.text,
        password: _password.text,
      );
    }
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final distributors = ref.watch(distributorsProvider).value ?? const [];
    ref.listen(authViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar'), leading: BackButton(onPressed: () => context.go('/login'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Distributor baru'), icon: Icon(Icons.business)),
                      ButtonSegment(value: false, label: Text('Pelanggan'), icon: Icon(Icons.storefront)),
                    ],
                    selected: {_asDistributor},
                    onSelectionChanged: (v) => setState(() => _asDistributor = v.first),
                  ),
                  if (!_asDistributor)
                    DropdownButtonFormField<String>(
                      initialValue: _distributorId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Belanja ke distributor'),
                      items: [for (final d in distributors) DropdownMenuItem(value: d.id, child: Text(d.name))],
                      onChanged: (v) => setState(() => _distributorId = v),
                      validator: (v) => v == null ? 'Pilih distributor' : null,
                    ),
                  TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama pemilik'), validator: _required),
                  TextFormField(
                    controller: _business,
                    decoration: InputDecoration(labelText: _asDistributor ? 'Nama distributor' : 'Nama toko / cafe'),
                    validator: _required,
                  ),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'No. HP / WhatsApp'),
                    validator: _required,
                  ),
                  if (!_asDistributor)
                    TextFormField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Alamat kirim'),
                      validator: _required,
                    ),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v ?? '').contains('@') ? null : 'Email tidak valid',
                  ),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v ?? '').length >= 6 ? null : 'Minimal 6 karakter',
                  ),
                  FilledButton(onPressed: state.isLoading ? null : _submit, child: const Text('Daftar')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
