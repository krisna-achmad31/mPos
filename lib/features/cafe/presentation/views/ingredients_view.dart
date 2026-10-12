import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../cafe_view_models.dart';

double _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

/// HPP per gram / ml bisa di bawah Rp10: tampilkan dengan desimal.
String _unitCost(double v) => v >= 10 ? formatRupiah(v.round()) : 'Rp${formatQty(v)}';

final _decimal = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

/// Stok bahan baku POS kopi. Bahan dari distributor bertambah otomatis saat pesanan diterima.
class IngredientsView extends ConsumerWidget {
  const IngredientsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Stok bahan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _IngredientDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Bahan'),
      ),
      body: AsyncValueView(
        value: ref.watch(ingredientsProvider),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Belum ada bahan.\nBelanja di distributor lalu konfirmasi "Diterima": bahan & stoknya masuk otomatis.',
            );
          }
          final value = list.fold(0.0, (s, i) => s + i.stockValue);
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              ListTile(
                title: Text('${list.length} bahan · ${list.where((i) => i.isLow).length} menipis'),
                trailing: Text('Nilai ${formatRupiah(value.round())}', style: Theme.of(context).textTheme.titleSmall),
              ),
              const Divider(height: 1),
              for (final i in list)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: i.isLow ? scheme.errorContainer : scheme.secondaryContainer,
                    child: Icon(
                      i.fromDistributor ? Icons.local_shipping_outlined : Icons.shopping_basket_outlined,
                      color: i.isLow ? scheme.onErrorContainer : scheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(i.name),
                  subtitle: Text([
                    if (i.fromDistributor) 'Dari distributor',
                    if (i.conversionLabel.isNotEmpty) i.conversionLabel,
                    'HPP ${_unitCost(i.avgCost)}/${i.unit}',
                  ].join(' · ')),
                  trailing: Text(
                    '${formatQty(i.stock)} ${i.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: i.isLow ? scheme.error : null,
                    ),
                  ),
                  onTap: () => _IngredientSheet.show(context, i),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Aksi untuk satu bahan.
class _IngredientSheet extends ConsumerWidget {
  const _IngredientSheet({required this.ingredient});

  final Ingredient ingredient;

  static Future<void> show(BuildContext context, Ingredient i) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _IngredientSheet(ingredient: i),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(ingredientMapProvider)[ingredient.id] ?? ingredient;
    final movements = ref.watch(ingredientMovementsProvider(ingredient.id)).value ?? const [];
    final text = Theme.of(context).textTheme;
    return FractionallySizedBox(
      heightFactor: 0.8,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(current.name, style: text.titleLarge),
          Text(
            'Stok ${formatQty(current.stock)} ${current.unit} · min ${formatQty(current.minStock)} ${current.unit}'
            '${current.conversionLabel.isEmpty ? '' : ' · ${current.conversionLabel}'}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _StockInDialog.show(context, current),
                icon: const Icon(Icons.add),
                label: const Text('Stok masuk'),
              ),
              OutlinedButton.icon(
                onPressed: () => _CountDialog.show(context, current),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Opname'),
              ),
              OutlinedButton.icon(
                onPressed: () => _IngredientDialog.show(context, initial: current),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Ubah'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final ok = await confirm(context, title: 'Hapus bahan', message: 'Hapus ${current.name}?');
                  if (!ok) return;
                  final vm = ref.read(cafeActionsViewModelProvider.notifier);
                  final deleted = await vm.deleteIngredient(current.id);
                  if (!context.mounted) return;
                  if (deleted) {
                    Navigator.pop(context);
                  } else {
                    showMessage(context, '${ref.read(cafeActionsViewModelProvider).error}', isError: true);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Riwayat stok', style: text.titleSmall),
          if (movements.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada riwayat.')),
          for (final m in movements.take(50))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(m.label),
              subtitle: Text('${formatDateTime(m.at)}${m.note.isEmpty ? '' : ' · ${m.note}'}'),
              trailing: Text(
                '${m.qty > 0 ? '+' : ''}${formatQty(m.qty)} ${current.unit}',
                style: TextStyle(color: m.qty < 0 ? Theme.of(context).colorScheme.error : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bahan baru (dibeli di luar distributor) atau ubah bahan.
class _IngredientDialog extends ConsumerStatefulWidget {
  const _IngredientDialog({this.initial});

  final Ingredient? initial;

  static Future<void> show(BuildContext context, {Ingredient? initial}) =>
      showDialog(context: context, builder: (_) => _IngredientDialog(initial: initial));

  @override
  ConsumerState<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends ConsumerState<_IngredientDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _unit = TextEditingController(text: widget.initial?.unit ?? 'gram');
  late final _purchaseUnit = TextEditingController(text: widget.initial?.purchaseUnit);
  late final _perPurchase = TextEditingController(text: formatQty(widget.initial?.perPurchase ?? 1));
  late final _min = TextEditingController(text: widget.initial == null ? '' : formatQty(widget.initial!.minStock));
  final _stock = TextEditingController();
  final _cost = TextEditingController();
  String? _error;

  bool get _isNew => widget.initial == null;

  @override
  void dispose() {
    for (final c in [_name, _unit, _purchaseUnit, _perPurchase, _min, _stock, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final stock = _parse(_stock.text);
    final base = widget.initial ?? const Ingredient(id: '', name: '', unit: '');
    final perPurchase = _parse(_perPurchase.text);
    final ingredient = base.copyWith(
      name: _name.text,
      unit: _unit.text,
      purchaseUnit: _purchaseUnit.text,
      perPurchase: perPurchase <= 0 ? 1 : perPurchase,
      minStock: _parse(_min.text),
      stock: _isNew ? stock : null,
      avgCost: _isNew && stock > 0 ? parseRupiah(_cost.text) / stock : null,
    );
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).saveIngredient(ingredient);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(cafeActionsViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    final small = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(
      title: Text(_isNew ? 'Bahan baru' : 'Ubah bahan'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama bahan')),
              TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Satuan resep', helperText: 'mis. gram, ml, pcs'),
                onChanged: (_) => setState(() {}),
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _purchaseUnit,
                      decoration: const InputDecoration(labelText: 'Satuan beli', helperText: 'mis. pack, kotak'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _perPurchase,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: _decimal,
                      decoration: InputDecoration(labelText: 'Isi per satuan beli', suffixText: _unit.text),
                    ),
                  ),
                ],
              ),
              Text(
                widget.initial?.fromDistributor ?? false
                    ? 'Contoh: biji kopi dibeli per pack 1 kg, resep memakai gram → satuan resep "gram", isi 1000. '
                        'Stok yang sudah ada ikut dikonversi.'
                    : 'Isi 1 bila satuan beli sama dengan satuan resep.',
                style: small,
              ),
              TextField(
                controller: _min,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: _decimal,
                decoration: InputDecoration(labelText: 'Batas stok minimum', suffixText: _unit.text),
              ),
              if (_isNew) ...[
                TextField(
                  controller: _stock,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _decimal,
                  decoration: InputDecoration(labelText: 'Stok awal (opsional)', suffixText: _unit.text),
                ),
                TextField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Total harga stok awal (Rp)', helperText: 'Untuk menghitung HPP'),
                ),
              ],
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}

/// Stok masuk di luar distributor (mis. beli susu di pasar).
class _StockInDialog extends ConsumerStatefulWidget {
  const _StockInDialog({required this.ingredient});

  final Ingredient ingredient;

  static Future<void> show(BuildContext context, Ingredient i) =>
      showDialog(context: context, builder: (_) => _StockInDialog(ingredient: i));

  @override
  ConsumerState<_StockInDialog> createState() => _StockInDialogState();
}

class _StockInDialogState extends ConsumerState<_StockInDialog> {
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();
  bool _inPurchaseUnit = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_qty, _cost, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final i = widget.ingredient;
    final qty = _parse(_qty.text) * (_inPurchaseUnit ? i.perPurchase : 1);
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).addStock(i.id, qty, parseRupiah(_cost.text), _note.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(cafeActionsViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.ingredient;
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    final canUsePurchase = i.purchaseUnit.isNotEmpty && i.perPurchase != 1;
    return AlertDialog(
      title: Text('Stok masuk · ${i.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            if (canUsePurchase)
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(i.unit)),
                  ButtonSegment(value: true, label: Text(i.purchaseUnit)),
                ],
                selected: {_inPurchaseUnit},
                onSelectionChanged: (v) => setState(() => _inPurchaseUnit = v.first),
              ),
            TextField(
              controller: _qty,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimal,
              decoration: InputDecoration(labelText: 'Jumlah', suffixText: _inPurchaseUnit ? i.purchaseUnit : i.unit),
            ),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Total harga beli (Rp)', helperText: 'Kosongkan bila HPP tidak berubah'),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan', hintText: 'mis. beli di pasar')),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}

/// Hitung fisik: stok diganti hasil hitung, selisih tercatat di riwayat.
class _CountDialog extends ConsumerStatefulWidget {
  const _CountDialog({required this.ingredient});

  final Ingredient ingredient;

  static Future<void> show(BuildContext context, Ingredient i) =>
      showDialog(context: context, builder: (_) => _CountDialog(ingredient: i));

  @override
  ConsumerState<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends ConsumerState<_CountDialog> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_counted.text.trim().isEmpty) {
      setState(() => _error = 'Isi hasil hitung.');
      return;
    }
    final vm = ref.read(cafeActionsViewModelProvider.notifier);
    final ok = await vm.countStock(widget.ingredient.id, _parse(_counted.text), _note.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(cafeActionsViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.ingredient;
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    return AlertDialog(
      title: Text('Opname · ${i.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text('Tercatat ${formatQty(i.stock)} ${i.unit}'),
            TextField(
              controller: _counted,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: _decimal,
              decoration: InputDecoration(labelText: 'Hasil hitung fisik', suffixText: i.unit),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan', hintText: 'mis. tumpah')),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
