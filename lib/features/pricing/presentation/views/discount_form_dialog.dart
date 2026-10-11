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
  late final _name = TextEditingController(text: widget.initial?.name);
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
    _name.dispose();
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

  Future<void> _save() async {
    final products = ref.read(activeProductsProvider).value ?? [];
    final customers = ref.read(customersProvider).value ?? [];
    final discount = Discount(
      id: widget.initial?.id ?? '',
      name: _name.text.trim(),
      kind: _kind,
      type: _type,
      value: double.tryParse(_value.text.replaceAll(',', '.')) ?? 0,
      productId: _productId,
      productName: products.where((p) => p.id == _productId).firstOrNull?.name ?? '',
      customerId: _customerId,
      customerName: customers.where((c) => c.uid == _customerId).firstOrNull?.displayName ?? '',
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
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              Text(
                isPromo
                    ? 'Promo untuk item tertentu, akun tertentu, atau keduanya.'
                    : 'Katalog customer tetap menampilkan harga normal; potongan baru terlihat di invoice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
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
              DropdownButtonFormField<String?>(
                initialValue: _customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: [
                  if (isPromo) const DropdownMenuItem(value: null, child: Text('Semua customer')),
                  for (final c in customers) DropdownMenuItem(value: c.uid, child: Text(c.displayName)),
                ],
                onChanged: (v) => setState(() => _customerId = v),
              ),
              DropdownButtonFormField<String?>(
                initialValue: _productId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Produk'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Semua produk')),
                  for (final p in products) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _productId = v),
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
