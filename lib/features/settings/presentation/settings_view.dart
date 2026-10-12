import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/png_logo.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/feedback.dart';
import '../domain/store_settings.dart';
import '../settings_providers.dart';
import '../../../core/router/app_shell.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Pengaturan Toko & Nota')),
      body: AsyncValueView(
        value: ref.watch(storeSettingsProvider),
        data: (settings) => _SettingsForm(initial: settings),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final StoreSettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _name = TextEditingController(text: widget.initial.storeName);
  late final _address = TextEditingController(text: widget.initial.address);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _email = TextEditingController(text: widget.initial.email);
  late final _tax = TextEditingController(text: '${widget.initial.taxPercent}');
  late final _bank = TextEditingController(text: widget.initial.bankInfo);
  late final _receiptFooter = TextEditingController(text: widget.initial.receiptFooter);
  late final _invoiceFooter = TextEditingController(text: widget.initial.invoiceFooter);
  late final _signature = TextEditingController(text: widget.initial.signatureName);
  late bool _taxEnabled = widget.initial.taxEnabled;
  late String _noteType = widget.initial.defaultNoteType;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _email, _tax, _bank, _receiptFooter, _invoiceFooter, _signature]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(settingsViewModelProvider.notifier).save(widget.initial.copyWith(
          storeName: _name.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          taxEnabled: _taxEnabled,
          taxPercent: double.tryParse(_tax.text.replaceAll(',', '.')) ?? 0,
          bankInfo: _bank.text.trim(),
          receiptFooter: _receiptFooter.text.trim(),
          invoiceFooter: _invoiceFooter.text.trim(),
          signatureName: _signature.text.trim(),
          defaultNoteType: _noteType,
        ));
    if (!mounted) return;
    showMessage(context, ok ? 'Pengaturan disimpan' : '${ref.read(settingsViewModelProvider).error}', isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(settingsViewModelProvider).isLoading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Text('Profil toko', style: Theme.of(context).textTheme.titleMedium),
                TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama toko')),
                TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat')),
                TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telepon')),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email (tampil di invoice)'),
                ),
                const _LogoSection(),
                Text('Pajak', style: Theme.of(context).textTheme.titleMedium),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktifkan pajak (PPN)'),
                  value: _taxEnabled,
                  onChanged: (v) => setState(() => _taxEnabled = v),
                ),
                if (_taxEnabled)
                  TextField(
                    controller: _tax,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Persentase pajak', suffixText: '%'),
                  ),
                Text('Nota', style: Theme.of(context).textTheme.titleMedium),
                DropdownButtonFormField<String>(
                  initialValue: _noteType,
                  decoration: const InputDecoration(labelText: 'Jenis nota default'),
                  items: const [
                    DropdownMenuItem(value: 'struk58', child: Text('Struk 58 mm')),
                    DropdownMenuItem(value: 'struk80', child: Text('Struk 80 mm')),
                    DropdownMenuItem(value: 'invoice', child: Text('Invoice A4')),
                    DropdownMenuItem(value: 'faktur', child: Text('Faktur')),
                  ],
                  onChanged: (v) => setState(() => _noteType = v ?? _noteType),
                ),
                TextField(controller: _bank, maxLines: 2, decoration: const InputDecoration(labelText: 'Rekening bank (tampil di invoice)')),
                TextField(controller: _receiptFooter, maxLines: 3, decoration: const InputDecoration(labelText: 'Footer struk')),
                TextField(controller: _invoiceFooter, maxLines: 2, decoration: const InputDecoration(labelText: 'Footer invoice / faktur')),
                TextField(controller: _signature, decoration: const InputDecoration(labelText: 'Nama penanda tangan (Hormat kami)')),
                FilledButton.icon(onPressed: busy ? null : _save, icon: const Icon(Icons.save), label: const Text('Simpan')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo distributor untuk invoice. Wajib PNG agar latar transparan tetap transparan di nota.
class _LogoSection extends ConsumerWidget {
  const _LogoSection();

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['png']);
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    final vm = ref.read(settingsViewModelProvider.notifier);
    final ok = await vm.saveLogo(bytes);
    if (!context.mounted) return;
    if (!ok) {
      showMessage(context, '${ref.read(settingsViewModelProvider).error}', isError: true);
    } else if (!pngHasTransparency(bytes)) {
      showMessage(context, 'Logo disimpan, tetapi PNG ini tidak punya latar transparan.');
    } else {
      showMessage(context, 'Logo disimpan');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(settingsViewModelProvider.notifier).removeLogo();
    if (!context.mounted) return;
    showMessage(context, ok ? 'Logo dihapus' : '${ref.read(settingsViewModelProvider).error}', isError: !ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(distributorLogoProvider).value;
    final busy = ref.watch(settingsViewModelProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      spacing: 16,
      children: [
        Container(
          width: 96,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: logo == null
              ? Text('Tanpa logo', style: Theme.of(context).textTheme.bodySmall)
              : Padding(padding: const EdgeInsets.all(6), child: Image.memory(logo, fit: BoxFit.contain)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('Logo invoice', style: Theme.of(context).textTheme.titleSmall),
              Text(
                'PNG transparan, maks ${maxLogoBytes ~/ 1024} KB. Tanpa logo, invoice hanya menampilkan nama distributor.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => _pick(context, ref),
                    icon: const Icon(Icons.upload),
                    label: Text(logo == null ? 'Unggah PNG' : 'Ganti'),
                  ),
                  if (logo != null)
                    TextButton(onPressed: busy ? null : () => _remove(context, ref), child: const Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
