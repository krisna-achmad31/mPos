import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/product_image.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/views/product_form_view.dart' show ProductImageField;
import '../../../products/product_providers.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../domain/cafe_rules.dart';
import '../cafe_view_models.dart';

/// Tambah / ubah menu beserta resepnya (takaran bahan per porsi).
class MenuFormView extends ConsumerStatefulWidget {
  const MenuFormView({super.key, this.menuId});

  final String? menuId;

  @override
  ConsumerState<MenuFormView> createState() => _MenuFormViewState();
}

class _RecipeRow {
  _RecipeRow({this.ingredientId, double qty = 0}) : qty = TextEditingController(text: qty == 0 ? '' : formatQty(qty));

  String? ingredientId;
  final TextEditingController qty;

  double get value => double.tryParse(qty.text.replaceAll(',', '.')) ?? 0;
}

class _MenuFormViewState extends ConsumerState<MenuFormView> {
  static const _defaultCategories = ['Kopi', 'Non Kopi', 'Makanan', 'Snack'];

  final _name = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _rows = <_RecipeRow>[];
  String _image = '';
  bool _active = true;
  bool _loaded = false;
  bool _processingImage = false;

  bool get _isNew => widget.menuId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) _loaded = true;
  }

  void _load(Product menu, Recipe? recipe) {
    _name.text = menu.name;
    _category.text = menu.category;
    _price.text = '${menu.sellPrice}';
    _image = menu.imageBase64;
    _active = menu.active;
    _rows
      ..clear()
      ..addAll([for (final l in recipe?.lines ?? const <RecipeLine>[]) _RecipeRow(ingredientId: l.ingredientId, qty: l.qty)]);
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _price, ..._rows.map((r) => r.qty)]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    setState(() => _processingImage = true);
    try {
      final encoded = await compute(encodeProductImage, await file.xFile.readAsBytes());
      if (mounted) setState(() => _image = encoded);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  Recipe get _recipe => Recipe(
        menuId: widget.menuId ?? '',
        lines: [
          for (final r in _rows)
            if (r.ingredientId != null) RecipeLine(ingredientId: r.ingredientId!, qty: r.value),
        ],
      );

  Future<void> _save() async {
    final ids = _rows.map((r) => r.ingredientId).whereType<String>().toList();
    if (ids.toSet().length != ids.length) {
      showMessage(context, 'Bahan yang sama muncul dua kali di resep.', isError: true);
      return;
    }
    final menu = Product(
      id: widget.menuId ?? '',
      name: _name.text.trim(),
      category: _category.text.trim(),
      unit: 'porsi',
      sellPrice: parseRupiah(_price.text),
      trackStock: false,
      active: _active,
      imageBase64: _image,
    );
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).saveMenu(menu, _recipe);
    if (!mounted) return;
    if (ok) {
      showMessage(context, 'Menu disimpan');
      context.go('/cafe/menu');
    } else {
      showMessage(context, '${ref.read(cafeActionsViewModelProvider).error}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final menu = ref.watch(productProvider(widget.menuId!));
      final recipes = ref.watch(recipesProvider);
      if (menu.hasValue && recipes.hasValue) {
        final m = menu.value;
        if (m == null) return const Scaffold(body: Center(child: Text('Menu tidak ditemukan')));
        _load(m, recipes.value![m.id]);
      } else {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    final ingredients = ref.watch(ingredientsProvider).value ?? const <Ingredient>[];
    final byId = {for (final i in ingredients) i.id: i};
    final cost = CafeRules.menuCost(_recipe, byId);
    final price = parseRupiah(_price.text);
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Menu baru' : 'Ubah menu'),
        leading: BackButton(onPressed: () => context.go('/cafe/menu')),
        actions: [
          FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  ProductImageField(
                    imageBase64: _image,
                    fallbackIcon: Icons.local_cafe_outlined,
                    busy: _processingImage,
                    onPick: _pickImage,
                    onRemove: () => setState(() => _image = ''),
                  ),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama menu *')),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _price,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Harga jual (Rp) *'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: TextField(controller: _category, decoration: const InputDecoration(labelText: 'Kategori')),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in _defaultCategories)
                        ChoiceChip(
                          label: Text(c),
                          selected: _category.text == c,
                          onSelected: (_) => setState(() => _category.text = c),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tampil di kasir'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const Divider(),
                  Text('Resep per porsi', style: text.titleMedium),
                  Text(
                    ingredients.isEmpty
                        ? 'Belum ada bahan. Bahan otomatis muncul saat pesanan distributor diterima, '
                            'atau tambahkan manual di Stok bahan.'
                        : 'Setiap porsi terjual memotong stok bahan sesuai takaran ini. Kosongkan bila menu tidak memakai bahan.',
                    style: text.bodySmall,
                  ),
                  for (final (index, row) in _rows.indexed)
                    Row(
                      key: ObjectKey(row),
                      spacing: 8,
                      children: [
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: byId.containsKey(row.ingredientId) ? row.ingredientId : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Bahan'),
                            items: [
                              for (final i in ingredients)
                                DropdownMenuItem(value: i.id, child: Text(i.name, overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => setState(() => row.ingredientId = v),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: row.qty,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                            decoration: InputDecoration(
                              labelText: 'Takaran',
                              suffixText: byId[row.ingredientId]?.unit,
                              helperText: byId[row.ingredientId] == null
                                  ? null
                                  : formatRupiah((row.value * byId[row.ingredientId]!.avgCost).round()),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus bahan',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _rows.removeAt(index).qty.dispose()),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: ingredients.isEmpty ? null : () => setState(() => _rows.add(_RecipeRow())),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah bahan'),
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        spacing: 4,
                        children: [
                          _row('HPP bahan per porsi', formatRupiah(cost)),
                          _row('Laba kotor per porsi', formatRupiah(price - cost)),
                          _row('Margin', price == 0 ? '-' : '${((price - cost) / price * 100).round()}%'),
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

  Widget _row(String label, String value) => Row(children: [Text(label), const Spacer(), Text(value)]);
}
