import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/product_image.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
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
  late List<BundleItem> _items = [...?widget.bundle?.bundleItems];
  late bool _active = widget.bundle?.active ?? true;
  late String _image = widget.bundle?.imageBase64 ?? '';
  bool _processingImage = false;
  int _pickerKey = 0;

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode]) {
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

  /// [bundlePrice] null = harga normal produk (default saat baru ditambahkan).
  BundleItem _itemFrom(Product p, int qty, {int? bundlePrice}) => BundleItem(
        productId: p.id,
        name: p.name,
        qty: qty,
        unit: p.unit,
        price: p.sellPrice,
        bundlePrice: bundlePrice ?? p.sellPrice,
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

  void _setPrice(int index, int price) =>
      setState(() => _items = [..._items]..[index] = _items[index].copyWith(bundlePrice: price));

  /// Nama & harga normal isi diperbarui dari produk terbaru; harga di paket tetap yang diinput.
  List<BundleItem> _freshItems(Map<String, Product> products) => [
        for (final i in _items)
          if (products[i.productId] case final p?) _itemFrom(p, i.qty, bundlePrice: i.bundlePrice) else i,
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
      sellPrice: BundleRules.bundlePrice(items),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final products = {for (final p in ref.watch(productsProvider).value ?? const <Product>[]) p.id: p};
    final costs = ref.watch(productUnitCostsProvider);

    final items = _freshItems(products);
    final normal = BundleRules.normalPrice(items);
    final cost = BundleRules.cost(items, (id) => InventorySummary.unitCost(costs[id]));
    final price = BundleRules.bundlePrice(items);
    final saving = normal - price;
    final preview = BundleRules.resolveStock([
      ...products.values,
      Product(id: '_preview', name: '', sellPrice: price, bundleItems: items),
    ]).last;

    Widget responsive(List<Widget> children) {
      if (context.deviceClass == DeviceClass.phone) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: AppSpacing.md, children: children);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [for (final c in children) Expanded(child: c)],
      );
    }

    return PageScaffold(
      leading: BackButton(onPressed: () => context.go('/owner/products')),
      title: widget.bundle == null ? 'Bundling baru' : 'Ubah bundling',
      subtitle: 'Produk / Bundle',
      actions: [
        FilledButton.icon(
          onPressed: state.isLoading || _processingImage ? null : () => _save(products, costs),
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Simpan paket'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Informasi paket',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
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
                  responsive([
                    TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
                    TextFormField(controller: _barcode, decoration: const InputDecoration(labelText: 'Barcode')),
                  ]),
                ],
              ),
            ),
            SectionCard(
              title: 'Isi paket',
              subtitle:
                  'Pilih produk, jumlah, dan harga per satuan di dalam paket. Saat paket terjual, stok tiap produk isi ikut berkurang.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [
                  ProductPicker(
                    key: ValueKey(_pickerKey),
                    label: 'Tambah produk ke bundling',
                    includeBundles: false,
                    onSelected: _add,
                  ),
                  if (items.isEmpty)
                    Text('Belum ada isi.', style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted))
                  else
                    Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) Divider(height: 1, color: tokens.line),
                          _ItemRow(
                            key: ValueKey(items[i].productId),
                            item: items[i],
                            product: products[items[i].productId],
                            onQty: (q) => _setQty(i, q),
                            onPrice: (v) => _setPrice(i, v),
                          ),
                        ],
                      ],
                    ),
                  if (items.isNotEmpty)
                    _Summary(
                      rows: [
                        ('Harga normal isi', formatRupiah(normal), null),
                        ('Harga bundling (jumlah harga isi)', price > 0 ? formatRupiah(price) : '-', null),
                        if (price > 0 && saving > 0)
                          (
                            'Pelanggan hemat',
                            '${formatRupiah(saving)} (${(saving * 100 / normal).round()}%)',
                            theme.colorScheme.primary,
                          ),
                        if (price > 0 && saving < 0)
                          ('Lebih mahal dari harga normal', formatRupiah(-saving), tokens.danger),
                        ('Modal (HPP isi)', formatRupiah(cost), null),
                        if (price > 0)
                          ('Laba per paket', formatRupiah(price - cost), price < cost ? tokens.danger : null),
                      ],
                    ),
                  if (preview.trackStock)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(
                        'Maksimal ${preview.stock} paket tersedia',
                        tone: BadgeTone.warning,
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                  Text(
                    'Stok komponen berkurang otomatis saat paket terjual.',
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                  if (price > 0 && price < cost)
                    Text(
                      'Harga bundling di bawah modal: setiap paket terjual rugi.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.danger),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif — tampil di katalog pelanggan'),
                    subtitle: const Text('Matikan untuk menyembunyikan paket dari katalog & kasir tanpa menghapusnya'),
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value, color) in rows) InfoRow(label: label, value: value, valueColor: color, bold: true),
      ],
    );
  }
}

/// Satu isi bundling: qty dan harga per satuan di paket.
class _ItemRow extends StatefulWidget {
  const _ItemRow({super.key, required this.item, required this.product, required this.onQty, required this.onPrice});

  final BundleItem item;
  final Product? product;
  final ValueChanged<int> onQty;
  final ValueChanged<int> onPrice;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final _price = TextEditingController(text: '${widget.item.bundlePrice}');

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final p = widget.product;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final tokens = context.tokens;
    final diff = item.price - item.bundlePrice;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(item.name, style: text.titleSmall),
                    Text(
                      [
                        'Normal ${formatRupiah(item.price)} / ${item.unit}',
                        if (p != null && p.trackStock) 'stok ${p.stock}',
                        if (p == null) 'produk tidak ditemukan',
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(color: p == null ? tokens.danger : tokens.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kurangi',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => widget.onQty(item.qty - 1),
              ),
              TextButton(
                onPressed: () async {
                  final q = await askQuantity(context, current: item.qty, unit: item.unit);
                  if (q != null) widget.onQty(q);
                },
                child: Text('${item.qty} ${item.unit}'),
              ),
              IconButton(
                tooltip: 'Tambah',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => widget.onQty(item.qty + 1),
              ),
              IconButton(
                tooltip: 'Hapus',
                icon: Icon(Icons.delete_outline, color: tokens.danger),
                onPressed: () => widget.onQty(0),
              ),
            ],
          ),
          Row(
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Harga di paket per ${item.unit} (Rp)',
                    helperText: diff > 0
                        ? 'Hemat ${formatRupiah(diff)} / ${item.unit}'
                        : diff < 0
                            ? 'Lebih mahal ${formatRupiah(-diff)} dari normal'
                            : 'Sama dengan harga normal',
                  ),
                  validator: (v) => parseRupiah(v ?? '') <= 0 ? 'Isi harga' : null,
                  onChanged: (v) => widget.onPrice(parseRupiah(v)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm, bottom: 18),
                child: Text('${item.qty} × = ${formatRupiah(item.bundleTotal)}', style: text.titleSmall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
