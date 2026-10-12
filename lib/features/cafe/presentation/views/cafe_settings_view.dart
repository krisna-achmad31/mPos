import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../settings/domain/store_settings.dart';
import '../../../settings/settings_providers.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../printing/bluetooth_printer.dart';
import '../cafe_view_models.dart';

/// Pengaturan POS kopi: kop struk, printer thermal, dan aturan stok.
class CafeSettingsView extends ConsumerWidget {
  const CafeSettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeSettingsProvider);
    final cafe = ref.watch(cafeSettingsProvider);
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Pengaturan & printer')),
      body: !store.hasValue || !cafe.hasValue
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        _PrinterCard(settings: cafe.value!),
                        _StockCard(settings: cafe.value!),
                        _ReceiptCard(initial: store.value!),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrinterCard extends ConsumerWidget {
  const _PrinterCard({required this.settings});

  final CafeSettings settings;

  Future<void> _save(BuildContext context, WidgetRef ref, CafeSettings s) async {
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).saveSettings(s);
    if (!ok && context.mounted) showMessage(context, '${ref.read(cafeActionsViewModelProvider).error}', isError: true);
  }

  Future<void> _choose(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(receiptPrintViewModelProvider.notifier);
    final devices = await vm.pairedDevices();
    if (!context.mounted) return;
    if (devices.isEmpty) {
      final error = vm.errorText;
      showMessage(
        context,
        error.isNotEmpty ? error : 'Belum ada printer terpasang. Pasangkan (pair) printer di pengaturan Bluetooth HP dulu.',
        isError: true,
      );
      return;
    }
    final picked = await showDialog<PrinterDevice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pilih printer'),
        children: [
          for (final d in devices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, d),
              child: ListTile(leading: const Icon(Icons.print), title: Text(d.name), subtitle: Text(d.address)),
            ),
        ],
      ),
    );
    if (picked != null && context.mounted) {
      await _save(context, ref, settings.copyWith(printerName: picked.name, printerAddress: picked.address));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bluetooth = ref.watch(receiptPrinterProvider).bluetoothSupported;
    final printing = ref.watch(receiptPrintViewModelProvider).isLoading;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('Printer thermal', style: text.titleMedium),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 58, label: Text('58 mm')),
                ButtonSegment(value: 80, label: Text('80 mm')),
              ],
              selected: {settings.paperWidth},
              onSelectionChanged: (v) => _save(context, ref, settings.copyWith(paperWidth: v.first)),
            ),
            if (bluetooth)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bluetooth),
                title: Text(settings.hasBluetoothPrinter ? settings.printerName : 'Belum memilih printer Bluetooth'),
                subtitle: Text(
                  settings.hasBluetoothPrinter
                      ? settings.printerAddress
                      : 'Pasangkan printer di pengaturan Bluetooth HP, lalu pilih di sini.',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (settings.hasBluetoothPrinter)
                      IconButton(
                        tooltip: 'Lupakan printer',
                        icon: const Icon(Icons.link_off),
                        onPressed: () => _save(context, ref, settings.copyWith(printerName: '', printerAddress: '')),
                      ),
                    OutlinedButton(onPressed: () => _choose(context, ref), child: const Text('Pilih')),
                  ],
                ),
              )
            else
              Text(
                'Printer Bluetooth tersedia di aplikasi Android / iOS. Di web, struk dicetak lewat dialog cetak '
                'browser: pilih printer thermal yang terpasang di komputer dan kertas ${settings.paperWidth} mm.',
                style: text.bodySmall,
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cetak otomatis setelah bayar'),
              value: settings.autoPrint,
              onChanged: (v) => _save(context, ref, settings.copyWith(autoPrint: v)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: printing
                    ? null
                    : () async {
                        final vm = ref.read(receiptPrintViewModelProvider.notifier);
                        final ok = await vm.printTest(settings);
                        if (context.mounted) showMessage(context, ok ? 'Struk uji dikirim' : vm.errorText, isError: !ok);
                      },
                icon: const Icon(Icons.print_outlined),
                label: const Text('Cetak struk uji'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockCard extends ConsumerWidget {
  const _StockCard({required this.settings});

  final CafeSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        title: const Text('Tetap jual saat stok bahan kurang'),
        subtitle: const Text(
          'Mati: kasir tidak bisa menjual menu yang bahannya kurang. '
          'Nyala: tetap bisa dijual, stok bahan menjadi minus sampai dikoreksi lewat opname.',
        ),
        value: settings.allowNegativeStock,
        onChanged: (v) => ref.read(cafeActionsViewModelProvider.notifier).saveSettings(settings.copyWith(allowNegativeStock: v)),
      ),
    );
  }
}

class _ReceiptCard extends ConsumerStatefulWidget {
  const _ReceiptCard({required this.initial});

  final StoreSettings initial;

  @override
  ConsumerState<_ReceiptCard> createState() => _ReceiptCardState();
}

class _ReceiptCardState extends ConsumerState<_ReceiptCard> {
  late final _name = TextEditingController(
    text: widget.initial.storeName.isNotEmpty && widget.initial.storeName != const StoreSettings().storeName
        ? widget.initial.storeName
        : ref.read(currentUserProvider).displayName,
  );
  late final _address = TextEditingController(text: widget.initial.address);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _footer = TextEditingController(text: widget.initial.receiptFooter);
  late final _tax = TextEditingController(text: '${widget.initial.taxPercent}');
  late bool _taxEnabled = widget.initial.taxEnabled;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _footer, _tax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).saveStoreSettings(
          widget.initial.copyWith(
            storeName: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
            receiptFooter: _footer.text.trim(),
            taxEnabled: _taxEnabled,
            taxPercent: double.tryParse(_tax.text.replaceAll(',', '.')) ?? widget.initial.taxPercent,
          ),
        );
    if (!mounted) return;
    showMessage(context, ok ? 'Pengaturan struk disimpan' : '${ref.read(cafeActionsViewModelProvider).error}', isError: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('Kop & footer struk', style: Theme.of(context).textTheme.titleMedium),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama kedai')),
            TextField(controller: _address, decoration: const InputDecoration(labelText: 'Alamat')),
            TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telepon / Instagram')),
            TextField(
              controller: _footer,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Footer struk', hintText: 'mis. Terima kasih, sampai jumpa lagi!'),
            ),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pajak / PB1'),
                    value: _taxEnabled,
                    onChanged: (v) => setState(() => _taxEnabled = v),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _tax,
                    enabled: _taxEnabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: const InputDecoration(suffixText: '%'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
            ),
          ],
        ),
      ),
    );
  }
}
