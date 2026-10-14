import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/product_image.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/bundle_rules.dart';
import '../../domain/services/inventory_summary.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';
import 'product_form_view.dart' show ProductImageField;

/// Kategori bawaan untuk bundling (dipakai juga untuk ikon).
const bundleCategory = 'Bundling';

/// Tambah / ubah bundling: beberapa produk dalam satu paket dengan harga sendiri.
class BundleForm extends ConsumerStatefulWidget {
  const BundleForm({super.key, required this.bundle});

  /// null = bundling baru.
  final Product? bundle;

  @override
  ConsumerState<BundleForm> createState() => _BundleFormState();
}

class _BundleFormState extends ConsumerState<BundleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bundle?.name);
  late final _sku = TextEditingController(text: widget.bundle?.sku);
  late final _barcode = TextEditingController(text: widget.bundle?.barcode);
  late final _price = TextEditingController(
    text: (widget.bundle?.sellPrice ?? 0) == 0 ? '' : '${widget.bundle!.sellPrice}',
  );
  late List<BundleItem> _items = [...?widget.bundle?.bundleItems];
  late bool _active = widget.bundle?.active ?? true;
  late String _image = widget.bundle?.imageBase64 ?? '';
  bool _processingImage = false;
  int _pickerKey = 0;

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    setState(() => _processingImage = true);
    try {
      final bytes = await file.xFile.readAsBytes();
      final encoded = await compute(encodeProductImage, bytes);
      if (mounted) setState(() => _image = encoded);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  BundleItem _itemFrom(Product p, int qty) => BundleItem(
        productId: p.id,
        name: p.name,
        qty: qty,
        unit: p.unit,
        price: p.sellPrice,
        trackStock: p.trackStock,
      );

  void _add(Product p) {
    setState(() {
      final i = _items.indexWhere((x) => x.productId == p.id);
      if (i >= 0) {
        _items[i] = _items[i].copyWith(qty: _items[i].qty + 1);
      } else {
        _items = [..._items, _itemFrom(p, 1)];
      }
      _pickerKey++;
    });
  }

  void _setQty(int index, int qty) => setState(() {
        if (qty <= 0) {
          _items = [..._items]..removeAt(index);
        } else {
          _items = [..._items]..[index] = _items[index].copyWith(qty: qty);
        }
      });

  /// Nama & harga isi diperbarui dari produk terbaru saat disimpan.
  List<BundleItem> _freshItems(Map<String, Product> products) => [
        for (final i in _items)
          if (products[i.productId] case final p?) _itemFrom(p, i.qty) else i,
      ];

  Future<void> _save(Map<String, Product> products, Map<String, ProductCost> costs) async {
    if (!_formKey.currentState!.validate()) return;
    final items = _freshItems(products);
    final base = widget.bundle ?? const Product(id: '', name: '', sellPrice: 0);
    final bundle = base.copyWith(
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: _barcode.text.trim(),
      category: base.category.isEmpty ? bundleCategory : base.category,
      unit: 'paket',
      sellPrice: parseRupiah(_price.text),
      wholesalePrice: 0,
      wholesaleMinQty: 0,
      minStock: 0,
      trackStock: false,
      active: _active,
      packs: const [],
      imageBase64: _image,
      bundleItems: items,
    );
    final cost = BundleRules.cost(items, (id) => InventorySummary.unitCost(costs[id]));
    final ok = await ref.read(productFormViewModelProvider.notifier).save(bundle, buyPrice: cost);
    if (ok && mounted) {
      showMessage(context, 'Bundling disimpan');
      context.go('/owner/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormViewModelProvider);
    ref.listen(productFormViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final products = {for (final p in ref.watch(productsProvider).value ?? const <Product>[]) p.id: p};
    final costs = ref.watch(productUnitCostsProvider);

    final items = _freshItems(products);
    final normal = BundleRules.normalPrice(items);
    final cost = BundleRules.cost(items, (id) => InventorySummary.unitCost(costs[id]));
    final price = parseRupiah(_price.text);
    final saving = normal - price;
    final preview = BundleRules.resolveStock([
      ...products.values,
      Product(id: '_preview', name: '', sellPrice: price, bundleItems: items),
    ]).last;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundle == null ? 'Bundling baru' : 'Ubah bundling'),
        leading: BackButton(onPressed: () => context.go('/owner/products')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
                      fallbackIcon: Icons.redeem_outlined,
                      busy: _processingImage,
                      onPick: _pickImage,
                      onRemove: () => setState(() => _image = ''),
                    ),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Nama bundling', hintText: 'mis. Paket Hemat Kopi Susu'),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                    Row(spacing: 12, children: [
                      Expanded(child: TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU'))),
                      Expanded(
                        child: TextFormField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode')),
                      ),
                    ]),
                    Text('Isi bundling', style: text.titleMedium),
                    Text(
                      'Pilih produk dan jumlahnya per paket. Saat paket terjual, stok tiap produk isi ikut berkurang.',
                      style: text.bodySmall,
                    ),
                    ProductPicker(
                      key: ValueKey(_pickerKey),
                      label: 'Tambah produk ke bundling',
                      includeBundles: false,
                      onSelected: _add,
                    ),
                    if (items.isEmpty)
                      Text('Belum ada isi.', style: text.bodyMedium?.copyWith(color: scheme.outline))
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              ListTile(
                                title: Text(items[i].name),
                                subtitle: Text(
                                  '${formatRupiah(items[i].price)} / ${items[i].unit}'
                                  '${products[items[i].productId]?.trackStock ?? false ? ' · stok ${products[items[i].productId]!.stock}' : ''}'
                                  '${products.containsKey(items[i].productId) ? '' : ' · produk tidak ditemukan'}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Kurangi',
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => _setQty(i, items[i].qty - 1),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final q = await askQuantity(context, current: items[i].qty, unit: items[i].unit);
                                        if (q != null) _setQty(i, q);
                                      },
                                      child: Text('${items[i].qty} ${items[i].unit}'),
                                    ),
                                    IconButton(
                                      tooltip: 'Tambah',
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => _setQty(i, items[i].qty + 1),
                                    ),
                                    IconButton(
                                      tooltip: 'Hapus',
                                      icon: Icon(Icons.delete_outline, color: scheme.error),
                                      onPressed: () => _setQty(i, 0),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    Text('Harga', style: text.titleMedium),
                    TextFormField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Harga bundling per paket (Rp)',
                        helperText: normal > 0 ? 'Harga normal isi: ${formatRupiah(normal)}' : null,
                      ),
                      validator: (v) => parseRupiah(v ?? '') <= 0 ? 'Isi harga bundling' : null,
                    ),
                    if (items.isNotEmpty)
                      _Summary(
                        rows: [
                          ('Harga normal isi', formatRupiah(normal), null),
                          ('Harga bundling', price > 0 ? formatRupiah(price) : '-', null),
                          if (price > 0 && saving > 0)
                            ('Pelanggan hemat', '${formatRupiah(saving)} (${(saving * 100 / normal).round()}%)', scheme.primary),
                          if (price > 0 && saving < 0)
                            ('Lebih mahal dari harga normal', formatRupiah(-saving), scheme.error),
                          ('Modal (HPP isi)', formatRupiah(cost), null),
                          if (price > 0)
                            ('Laba per paket', formatRupiah(price - cost), price < cost ? scheme.error : null),
                          ('Stok paket tersedia', preview.trackStock ? '${preview.stock} paket' : 'tanpa batas stok', null),
                        ],
                      ),
                    if (price > 0 && price < cost)
                      Text(
                        'Harga bundling di bawah modal: setiap paket terjual rugi.',
                        style: text.bodyMedium?.copyWith(color: scheme.error),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktif — tampil di katalog pelanggan'),
                      subtitle: const Text('Matikan untuk menyembunyikan paket dari katalog & kasir tanpa menghapusnya'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    FilledButton.icon(
                      onPressed: state.isLoading || _processingImage ? null : () => _save(products, costs),
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan bundling'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  final List<(String, String, Color?)> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 8,
          children: [
            for (final (label, value, color) in rows)
              Row(
                children: [
                  Expanded(child: Text(label, style: text.bodyMedium?.copyWith(color: color))),
                  Text(value, style: text.titleSmall?.copyWith(color: color)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
