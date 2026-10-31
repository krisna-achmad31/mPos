import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_providers.dart';
import '../viewmodels/pos_view_model.dart';

/// Pelanggan berakun, pembeli tanpa akun, atau transaksi umum.
class PosCustomerField extends ConsumerWidget {
  const PosCustomerField({super.key});
  static const _guest = Object();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(posViewModelProvider);
    final vm = ref.read(posViewModelProvider.notifier);
    final customers = ref.watch(customersProvider).value ?? [];
    final guest = state.guestCustomerName.isNotEmpty;
    final busy = state.submission.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<Object>(
          key: ValueKey((state.customer?.uid, state.guestCustomerName)),
          initialValue: state.customer?.uid ?? (guest ? _guest : null),
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Pelanggan'),
          items: [
            const DropdownMenuItem(value: null, child: Text('UMUM')),
            if (guest) DropdownMenuItem(value: _guest, child: Text('${state.guestCustomerName} (tanpa akun)')),
            for (final customer in customers) DropdownMenuItem(value: customer.uid, child: Text(customer.displayName)),
            if (state.customer != null && !customers.any((c) => c.uid == state.customer!.uid))
              DropdownMenuItem(value: state.customer!.uid, child: Text(state.customer!.displayName)),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == _guest) return;
                  vm.setCustomer(customers.where((c) => c.uid == value).firstOrNull);
                },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: Icon(guest ? Icons.edit_outlined : Icons.person_add_alt_outlined, size: 18),
            label: Text(guest ? 'Ubah nama pelanggan' : 'Tambah pelanggan tanpa akun'),
            onPressed: busy
                ? null
                : () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (_) => _GuestCustomerDialog(initialName: state.guestCustomerName),
                    );
                    if (name != null && context.mounted) vm.setGuestCustomer(name);
                  },
          ),
        ),
        if (guest)
          Text('Nama pelanggan akan tercatat di nota dan laporan.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _GuestCustomerDialog extends StatefulWidget {
  const _GuestCustomerDialog({required this.initialName});
  final String initialName;
  @override
  State<_GuestCustomerDialog> createState() => _GuestCustomerDialogState();
}

class _GuestCustomerDialogState extends State<_GuestCustomerDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pelanggan tanpa akun'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nama pelanggan / toko',
          helperText: 'Untuk pembelian langsung atau lewat WhatsApp.',
        ),
        validator: (value) => (value ?? '').trim().isEmpty ? 'Nama pelanggan wajib diisi' : null,
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
      FilledButton(onPressed: _save, child: const Text('Pakai nama ini')),
    ],
  );
}
