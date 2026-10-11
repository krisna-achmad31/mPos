import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../auth/auth_providers.dart';
import '../../../products/product_providers.dart';
import '../../domain/entities/discount.dart';
import '../viewmodels/discount_view_model.dart';

class DiscountFormDialog extends ConsumerStatefulWidget {
  const DiscountFormDialog({super.key, this.initial});

  final Discount? initial;

  static Future<void> show(BuildContext context, {Discount? initial}) =>
      showDialog(context: context, builder: (_) => DiscountFormDialog(initial: initial));

  @override
  ConsumerState<DiscountFormDialog> createState() => _DiscountFormDialogState();
}

class _DiscountFormDialogState extends ConsumerState<DiscountFormDialog> {
  static const _all = '__all__';

  late final _value = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.value.toStringAsFixed(widget.initial!.value % 1 == 0 ? 0 : 1));
  late DiscountKind _kind = widget.initial?.kind ?? DiscountKind.special;
  late DiscountType _type = widget.initial?.type ?? DiscountType.percent;
  late String? _productId = widget.initial?.productId;
  late String? _customerId = widget.initial?.customerId;
  late bool _visible = widget.initial?.visibleInCatalog ?? false;
  late DateTime? _start = widget.initial?.start;
  late DateTime? _end = widget.initial?.end;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _start : _end) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked.add(const Duration(days: 1)));
  }

  /// Nama dibuat otomatis dari pilihan, jadi tidak perlu diketik.
  String _autoName(String productName, String customerName) {
    final product = productName.isEmpty ? 'semua produk' : productName;
    return _kind == DiscountKind.special
        ? 'Harga khusus ${customerName.isEmpty ? '-' : customerName} · $product'
        : 'Promo $product${customerName.isEmpty ? '' : ' · $customerName'}';
  }

  Future<void> _save() async {
    final products = ref.read(activeProductsProvider).value ?? [];
    final customers = ref.read(customersProvider).value ?? [];
    final productName = products.where((p) => p.id == _productId).firstOrNull?.name ?? '';
    final customerName = customers.where((c) => c.uid == _customerId).firstOrNull?.displayName ?? '';
    final discount = Discount(
      id: widget.initial?.id ?? '',
      name: _autoName(productName, customerName),
      kind: _kind,
      type: _type,
      value: double.tryParse(_value.text.replaceAll(',', '.')) ?? 0,
      productId: _productId,
      productName: productName,
      customerId: _customerId,
      customerName: customerName,
      visibleInCatalog: _visible,
      start: _start,
      end: _end,
      active: widget.initial?.active ?? true,
    );
    final ok = await ref.read(discountViewModelProvider.notifier).save(discount);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(discountViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(activeProductsProvider).value ?? [];
    final customers = ref.watch(customersProvider).value ?? [];
    final isPromo = _kind == DiscountKind.promo;
    final canShowInCatalog = isPromo && _customerId == null;

    return AlertDialog(
      title: Text(widget.initial == null ? 'Diskon baru' : 'Ubah diskon'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              SegmentedButton<DiscountKind>(
                segments: const [
                  ButtonSegment(value: DiscountKind.special, label: Text('Harga khusus')),
                  ButtonSegment(value: DiscountKind.promo, label: Text('Promo')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() {
                  _kind = s.first;
                  if (_kind == DiscountKind.special) _visible = false;
                }),
              ),
              Text(
                isPromo
                    ? 'Promo untuk item tertentu, akun tertentu, atau keduanya.'
                    : 'Katalog customer tetap menampilkan harga normal; potongan baru terlihat di invoice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Nilai',
                        suffixText: _type == DiscountType.percent ? '%' : 'Rp / unit',
                      ),
                    ),
                  ),
                  SegmentedButton<DiscountType>(
                    segments: const [
                      ButtonSegment(value: DiscountType.percent, label: Text('%')),
                      ButtonSegment(value: DiscountType.amount, label: Text('Rp')),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                ],
              ),
              DropdownMenu<String>(
                key: ValueKey('customer-$_kind'),
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                requestFocusOnTap: true,
                leadingIcon: const Icon(Icons.storefront_outlined),
                label: Text(isPromo ? 'Pelanggan (opsional)' : 'Pelanggan *'),
                helperText: isPromo ? null : 'Hanya pelanggan ini yang mendapat harga khusus',
                initialSelection: _customerId ?? (isPromo ? _all : null),
                dropdownMenuEntries: [
                  if (isPromo) const DropdownMenuEntry(value: _all, label: 'Semua pelanggan'),
                  for (final c in customers) DropdownMenuEntry(value: c.uid, label: c.displayName),
                ],
                onSelected: (v) => setState(() => _customerId = v == null || v == _all ? null : v),
              ),
              DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero,
                enableFilter: true,
                requestFocusOnTap: true,
                menuHeight: 320,
                leadingIcon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Produk'),
                helperText: 'Ketik untuk mencari dari daftar produk',
                initialSelection: _productId ?? _all,
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: _all, label: 'Semua produk'),
                  for (final p in products) DropdownMenuEntry(value: p.id, label: p.name),
                ],
                onSelected: (v) => setState(() => _productId = v == null || v == _all ? null : v),
              ),
              Text(
                'Nama: ${_autoName(
                  products.where((p) => p.id == _productId).firstOrNull?.name ?? '',
                  customers.where((c) => c.uid == _customerId).firstOrNull?.displayName ?? '',
                )}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(true),
                      child: Text(_start == null ? 'Mulai: sekarang' : 'Mulai ${formatDate(_start!)}'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(false),
                      child: Text(_end == null
                          ? 'Selesai: tanpa batas'
                          : 'Sampai ${formatDate(_end!.subtract(const Duration(days: 1)))}'),
                    ),
                  ),
                ],
              ),
              if (canShowInCatalog)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tampilkan di katalog (harga coret)'),
                  subtitle: const Text('Matikan agar promo hanya terlihat di invoice'),
                  value: _visible,
                  onChanged: (v) => setState(() => _visible = v),
                ),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: ref.watch(discountViewModelProvider).isLoading ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
