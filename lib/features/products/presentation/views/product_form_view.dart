import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/product_image.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../domain/entities/product.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';
import 'product_list_view.dart' show categoryIcon;

/// Tambah / ubah produk. [productId] null berarti produk baru.
class ProductFormView extends ConsumerWidget {
  const ProductFormView({super.key, this.productId});

  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) return const _ProductForm(product: null, cost: null);

    final product = ref.watch(productProvider(id));
    final cost = ref.watch(productCostProvider(id));
    if (product.isLoading || cost.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (product.value == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Produk tidak ditemukan')));
    }
    return _ProductForm(product: product.value, cost: cost.value);
  }
}

class _ProductForm extends ConsumerStatefulWidget {
  const _ProductForm({required this.product, required this.cost});

  final Product? product;
  final ProductCost? cost;

  @override
  ConsumerState<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _sku = TextEditingController(text: widget.product?.sku);
  late final _barcode = TextEditingController(text: widget.product?.barcode);
  late String? _category = (widget.product?.category ?? '').isEmpty ? null : widget.product!.category;

  // Harga per kemasan: karton / ball / pouch (isi dalam satuan dasar + harga per kemasan).
  late final _packContents = {
    for (final name in ProductPack.presetNames)
      name: TextEditingController(text: _num(_existingPack(name)?.contents)),
  };
  late final _packPrice = {
    for (final name in ProductPack.presetNames) name: TextEditingController(text: _num(_existingPack(name)?.price)),
  };

  ProductPack? _existingPack(String name) =>
      widget.product?.packs.where((p) => p.name.toLowerCase() == name).firstOrNull;
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'pcs');
  late final _buyPrice = TextEditingController(text: _num(widget.cost?.buyPrice));
  late final _sellPrice = TextEditingController(text: _num(widget.product?.sellPrice));
  late final _wholesalePrice = TextEditingController(text: _num(widget.product?.wholesalePrice));
  late final _wholesaleMin = TextEditingController(text: _num(widget.product?.wholesaleMinQty));
  late final _minStock = TextEditingController(text: _num(widget.product?.minStock));
  late bool _trackStock = widget.product?.trackStock ?? true;
  late bool _active = widget.product?.active ?? true;
  late String _image = widget.product?.imageBase64 ?? '';
  bool _processingImage = false;

  Future<void> _pickImage() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    setState(() => _processingImage = true);
    try {
      final bytes = await file.xFile.readAsBytes();
      // Di HP diproses di isolate lain agar layar tidak macet.
      final encoded = await compute(encodeProductImage, bytes);
      if (mounted) setState(() => _image = encoded);
    } catch (e) {
      if (mounted) showMessage(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  static String _num(int? v) => v == null || v == 0 ? '' : '$v';

  @override
  void dispose() {
    for (final c in [
      _name, _sku, _barcode, _unit, _buyPrice, _sellPrice, _wholesalePrice, _wholesaleMin, _minStock,
      ..._packContents.values, ..._packPrice.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.product ?? const Product(id: '', name: '', sellPrice: 0);
    final product = base.copyWith(
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: _barcode.text.trim(),
      category: _category ?? '',
      packs: [
        for (final name in ProductPack.presetNames)
          if (parseRupiah(_packContents[name]!.text) > 1 && parseRupiah(_packPrice[name]!.text) > 0)
            ProductPack(
              name: name,
              contents: parseRupiah(_packContents[name]!.text),
              price: parseRupiah(_packPrice[name]!.text),
            ),
      ],
      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      sellPrice: parseRupiah(_sellPrice.text),
      wholesalePrice: parseRupiah(_wholesalePrice.text),
      wholesaleMinQty: parseRupiah(_wholesaleMin.text),
      minStock: parseRupiah(_minStock.text),
      trackStock: _trackStock,
      active: _active,
      imageBase64: _image,
    );
    final ok = await ref
        .read(productFormViewModelProvider.notifier)
        .save(product, buyPrice: parseRupiah(_buyPrice.text));
    if (ok && mounted) {
      showMessage(context, 'Produk disimpan');
      context.go('/owner/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormViewModelProvider);
    ref.listen(productFormViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    final digits = [FilteringTextInputFormatter.digitsOnly];

    Widget field(TextEditingController c, String label, {bool number = false, bool required = false, String? helper}) =>
        TextFormField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? digits : null,
          decoration: InputDecoration(labelText: label, helperText: helper),
          validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null : null,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Produk baru' : 'Ubah produk'),
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
                      fallbackIcon: categoryIcon(_category ?? ''),
                      busy: _processingImage,
                      onPick: _pickImage,
                      onRemove: () => setState(() => _image = ''),
                    ),
                    field(_name, 'Nama produk', required: true),
                    Row(spacing: 12, children: [
                      Expanded(child: field(_sku, 'SKU')),
                      Expanded(child: field(_barcode, 'Barcode')),
                    ]),
                    Row(spacing: 12, children: [
                      Expanded(child: _CategoryField(value: _category, onChanged: (v) => setState(() => _category = v))),
                      Expanded(child: field(_unit, 'Satuan dasar', helper: 'mis. pcs, botol, kotak')),
                    ]),
                    Text('Harga', style: Theme.of(context).textTheme.titleMedium),
                    Row(spacing: 12, children: [
                      Expanded(child: field(_buyPrice, 'Harga beli (Rp)', number: true)),
                      Expanded(child: field(_sellPrice, 'Harga jual satuan (Rp)', number: true, required: true)),
                    ]),
                    Row(spacing: 12, children: [
                      Expanded(child: field(_wholesalePrice, 'Harga grosir (Rp)', number: true, helper: 'Kosongkan bila tidak ada')),
                      Expanded(child: field(_wholesaleMin, 'Qty minimal grosir', number: true)),
                    ]),
                    Text('Harga per kemasan', style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      'Isi = jumlah satuan dasar per kemasan. Pembelian otomatis dipecah ke kemasan terbesar dulu, '
                      'mis. beli 25 dengan karton isi 20 → 1 karton + 5 satuan. Kosongkan yang tidak dipakai.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    for (final name in ProductPack.presetNames)
                      Row(spacing: 12, children: [
                        SizedBox(
                          width: 72,
                          child: Text(name[0].toUpperCase() + name.substring(1),
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        Expanded(child: field(_packContents[name]!, 'Isi per $name', number: true)),
                        Expanded(child: field(_packPrice[name]!, 'Harga per $name (Rp)', number: true)),
                      ]),
                    Text('Stok', style: Theme.of(context).textTheme.titleMedium),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Hitung stok'),
                      subtitle: const Text('Matikan untuk jasa atau barang tanpa stok'),
                      value: _trackStock,
                      onChanged: (v) => setState(() => _trackStock = v),
                    ),
                    if (_trackStock)
                      field(_minStock, 'Stok minimum (order ulang)', number: true,
                          helper: 'Peringatan muncul saat stok sama atau di bawah angka ini'),
                    if (widget.product != null)
                      Text('Stok saat ini: ${widget.product!.stock} ${widget.product!.unit}. '
                          'Stok berubah lewat stok masuk, penjualan, atau stock opname.'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aktif dijual'),
                      value: _active,
                      onChanged: (v) => setState(() => _active = v),
                    ),
                    FilledButton.icon(
                      onPressed: state.isLoading || _processingImage ? null : _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan'),
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

/// Kategori dipilih dari daftar; Owner bisa menambah kategori baru.
class _CategoryField extends ConsumerWidget {
  const _CategoryField({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await askReason(context, title: 'Kategori baru', label: 'Nama kategori');
    if (name == null) return;
    try {
      onChanged(await ref.read(categoryRepositoryProvider).add(name));
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [...ref.watch(categoriesProvider).value ?? const <String>[]];
    // Kategori lama yang belum ada di daftar tetap bisa tampil.
    if (value != null && !categories.contains(value)) categories.add(value!);
    return Row(
      spacing: 4,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(value),
            initialValue: value,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: onChanged,
            validator: (v) => v == null ? 'Pilih kategori' : null,
          ),
        ),
        IconButton(
          tooltip: 'Tambah kategori',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _add(context, ref),
        ),
      ],
    );
  }
}

/// Foto produk / menu: pratinjau + unggah / ganti / hapus. Tanpa foto memakai ikon kategori.
class ProductImageField extends StatelessWidget {
  const ProductImageField({
    super.key,
    required this.imageBase64,
    required this.fallbackIcon,
    required this.busy,
    required this.onPick,
    required this.onRemove,
  });

  final String imageBase64;
  final IconData fallbackIcon;
  final bool busy;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageBase64.isNotEmpty;
    return Row(
      spacing: 16,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            ProductImageView(imageBase64: imageBase64, fallbackIcon: fallbackIcon, size: 96),
            if (busy) const CircularProgressIndicator(),
          ],
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('Foto produk', style: Theme.of(context).textTheme.titleSmall),
              Text(
                busy
                    ? 'Memproses foto…'
                    : 'JPG / PNG / WebP. Otomatis diperkecil ke $productImageMaxSide px. '
                        'Tanpa foto, produk memakai gambar default.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPick,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(hasImage ? 'Ganti foto' : 'Unggah foto'),
                  ),
                  if (hasImage) TextButton(onPressed: busy ? null : onRemove, child: const Text('Hapus')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
