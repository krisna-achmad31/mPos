import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/utils/product_image.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../settings/domain/store_settings.dart';
import '../../../settings/settings_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/price_suggestion.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';
import 'bundle_form_view.dart';
import 'product_list_view.dart' show categoryIcon;

/// Tambah / ubah produk. [productId] null berarti produk baru.
class ProductFormView extends ConsumerWidget {
  const ProductFormView({super.key, this.productId, this.bundle = false});

  final String? productId;

  /// Produk baru berupa bundling.
  final bool bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = productId;
    if (id == null) return bundle ? const BundleForm(bundle: null) : const _ProductForm(product: null, cost: null);

    final product = ref.watch(productProvider(id));
    final cost = ref.watch(productCostProvider(id));
    if (product.isLoading || cost.isLoading) {
      return PageScaffold(
        leading: BackButton(onPressed: () => context.go('/owner/products')),
        title: 'Produk',
        child: const Center(
          child: Padding(padding: EdgeInsets.all(AppSpacing.xxxl), child: CircularProgressIndicator()),
        ),
      );
    }
    if (product.value == null) {
      return PageScaffold(
        leading: BackButton(onPressed: () => context.go('/owner/products')),
        title: 'Detail produk',
        child: const EmptyState(icon: Icons.search_off, message: 'Produk tidak ditemukan'),
      );
    }
    if (product.value!.isBundle) return BundleForm(bundle: product.value);
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

  // Harga per kemasan: karton / bal / sak / pouch (isi dalam satuan dasar + harga per kemasan).
  late final _packContents = {
    for (final name in ProductPack.presetNames) name: TextEditingController(text: _num(_existingPack(name)?.contents)),
  };
  late final _packPrice = {
    for (final name in ProductPack.presetNames) name: TextEditingController(text: _num(_existingPack(name)?.price)),
  };

  ProductPack? _existingPack(String name) =>
      widget.product?.packs.where((p) => ProductPack.canonicalName(p.name) == name).firstOrNull;
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

  String get _unitLabel => _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim();

  /// Pouch hanya tampil untuk produk lama yang sudah memakainya.
  late final _showPouch = _existingPack('pouch') != null;

  @override
  void initState() {
    super.initState();
    // Label "1 karton = 24 pcs", peringatan barcode, dan saran harga ikut berubah saat diketik.
    for (final c in [_unit, _barcode, _buyPrice, _sellPrice, ..._packContents.values]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _name,
      _sku,
      _barcode,
      _unit,
      _buyPrice,
      _sellPrice,
      _wholesalePrice,
      _wholesaleMin,
      _minStock,
      ..._packContents.values,
      ..._packPrice.values,
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    Widget field(TextEditingController c, String label, {bool number = false, bool required = false, String? helper}) =>
        TextFormField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          inputFormatters: number ? digits : null,
          decoration: InputDecoration(labelText: label, helperText: helper),
          validator: required ? (v) => (v ?? '').trim().isEmpty ? 'Wajib diisi' : null : null,
        );

    Widget responsive(List<Widget> children) {
      if (context.deviceClass == DeviceClass.phone) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.md,
          children: children,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.md,
        children: [for (final c in children) Expanded(child: c)],
      );
    }

    return PageScaffold(
      leading: BackButton(onPressed: () => context.go('/owner/products')),
      title: widget.product?.name ?? 'Produk baru',
      subtitle: widget.product == null ? 'Produk / Produk baru' : 'Produk / Detail produk',
      actions: [
        FilledButton.icon(
          onPressed: state.isLoading || _processingImage ? null : _save,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Simpan'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: 'Informasi produk',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [
                  ProductImageField(
                    imageBase64: _image,
                    fallbackIcon: categoryIcon(_category ?? ''),
                    busy: _processingImage,
                    onPick: _pickImage,
                    onRemove: () => setState(() => _image = ''),
                  ),
                  field(_name, 'Nama produk', required: true),
                  responsive([field(_sku, 'SKU'), field(_barcode, 'Barcode')]),
                  _BarcodeWarning(barcode: _barcode.text, productId: widget.product?.id ?? ''),
                  responsive([
                    _CategoryField(value: _category, onChanged: (v) => setState(() => _category = v)),
                    field(_unit, 'Satuan jual', helper: 'Satuan terkecil, mis. pcs atau kg'),
                  ]),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final u in Product.unitPresets)
                        ChoiceChip(
                          label: Text(u),
                          selected: _unit.text.trim() == u,
                          onSelected: (_) => setState(() => _unit.text = u),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Harga & inventori',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.md,
                children: [
                  responsive([
                    field(_buyPrice, 'Harga beli (Rp)', number: true),
                    field(_sellPrice, 'Harga jual satuan (Rp)', number: true, required: true),
                  ]),
                  _PriceSuggestionPanel(
                    // Produk lama: HPP rata-rata dari stok masuk. Produk baru: HPP awal = harga beli.
                    hpp: widget.product != null && (widget.cost?.hpp ?? 0) > 0
                        ? widget.cost!.hpp
                        : parseRupiah(_buyPrice.text),
                    isAverage: widget.product != null && (widget.cost?.hpp ?? 0) > 0,
                    unit: _unitLabel,
                    sellPrice: parseRupiah(_sellPrice.text),
                    onUse: (price) => _sellPrice.text = '$price',
                  ),
                  responsive([
                    field(_wholesalePrice, 'Harga grosir (Rp)', number: true, helper: 'Kosongkan bila tidak ada'),
                    field(_wholesaleMin, 'Qty minimal grosir', number: true),
                  ]),
                  Text('Isi kemasan', style: theme.textTheme.titleSmall),
                  Text(
                    'Selain per $_unitLabel, produk bisa dijual per karton / bal / sak. Isi = berapa $_unitLabel dalam '
                    'satu kemasan. Pembelian otomatis dipecah ke kemasan terbesar dulu, mis. beli 25 dengan karton '
                    'isi 20 → 1 karton + 5 $_unitLabel. Kosongkan yang tidak dipakai.',
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                  for (final name in ProductPack.presetNames)
                    if (name != 'pouch' || _showPouch)
                      responsive([
                        Text(
                          name[0].toUpperCase() + name.substring(1),
                          style: theme.textTheme.titleSmall,
                        ),
                        field(
                          _packContents[name]!,
                          'Isi per $name ($_unitLabel)',
                          number: true,
                          helper: parseRupiah(_packContents[name]!.text) > 1
                              ? '1 $name = ${parseRupiah(_packContents[name]!.text)} $_unitLabel'
                              : null,
                        ),
                        field(_packPrice[name]!, 'Harga per $name (Rp)', number: true),
                      ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hitung stok'),
                    subtitle: const Text('Matikan untuk jasa atau barang tanpa stok'),
                    value: _trackStock,
                    onChanged: (v) => setState(() => _trackStock = v),
                  ),
                  if (_trackStock)
                    field(
                      _minStock,
                      'Stok minimum (order ulang)',
                      number: true,
                      helper: 'Peringatan muncul saat stok sama atau di bawah angka ini',
                    ),
                  if (widget.product != null)
                    Text(
                      'Stok saat ini: ${widget.product!.stock} ${widget.product!.unit}. '
                      'Stok berubah lewat stok masuk, penjualan, atau stock opname.',
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif dijual'),
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

/// Peringatan langsung saat barcode sudah dipakai produk lain (simpan tetap ditolak ViewModel).
class _BarcodeWarning extends ConsumerWidget {
  const _BarcodeWarning({required this.barcode, required this.productId});

  final String barcode;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final taken = BarcodeRules.owner(products, barcode, excludeId: productId);
    if (taken == null) return const SizedBox.shrink();
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: tokens.dangerTint, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Text(barcodeTakenMessage(taken), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.danger)),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(onPressed: () => context.go('/owner/products/${taken.id}'), child: const Text('Buka produk itu')),
              FilledButton.tonal(onPressed: () => context.go('/owner/stock-in'), child: const Text('Ke Stok Masuk')),
            ],
          ),
        ],
      ),
    );
  }
}

/// HPP rata-rata + saran harga jual dari margin di Pengaturan. Tombol "Pakai" hanya mengisi kolom harga jual.
class _PriceSuggestionPanel extends ConsumerWidget {
  const _PriceSuggestionPanel({
    required this.hpp,
    required this.isAverage,
    required this.unit,
    required this.sellPrice,
    required this.onUse,
  });

  final int hpp;
  final bool isAverage;
  final String unit;
  final int sellPrice;
  final ValueChanged<int> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (hpp <= 0) return const SizedBox.shrink();
    final settings = ref.watch(storeSettingsProvider).value ?? const StoreSettings();
    final suggested = settings.suggestPrice(hpp);
    final margin = PriceSuggestion.marginOf(sellPrice, hpp);
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final label = theme.textTheme.bodySmall?.copyWith(color: tokens.muted);
    final value = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700);

    final (String, Color)? note = switch (sellPrice) {
      <= 0 => null,
      final p when p < hpp => ('Harga jual di bawah modal: rugi ${formatRupiah(hpp - p)} per $unit.', tokens.danger),
      final p when p < suggested => ('Margin sekarang $margin%, di bawah target ${_pct(settings.marginPercent)}%.', tokens.warning),
      _ => ('Margin sekarang $margin%.', tokens.success),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: tokens.primaryTint, borderRadius: BorderRadius.circular(AppRadius.control)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAverage ? 'HPP rata-rata (dari stok masuk)' : 'HPP awal', style: label),
                  Text('${formatRupiah(hpp)} / $unit', style: value),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Saran harga jual (margin ${_pct(settings.marginPercent)}%)', style: label),
                  Text(formatRupiah(suggested), style: value),
                ],
              ),
              if (sellPrice != suggested)
                FilledButton.tonal(onPressed: () => onUse(suggested), child: const Text('Pakai harga ini')),
            ],
          ),
          if (note != null) Text(note.$1, style: theme.textTheme.bodySmall?.copyWith(color: note.$2)),
        ],
      ),
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
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
      spacing: AppSpacing.xs,
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final hasImage = imageBase64.isNotEmpty;
    return Row(
      spacing: AppSpacing.lg,
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
            spacing: AppSpacing.xs,
            children: [
              Text('Foto produk', style: theme.textTheme.titleSmall),
              Text(
                busy
                    ? 'Memproses foto…'
                    : 'JPG / PNG / WebP. Otomatis diperkecil ke $productImageMaxSide px. '
                          'Tanpa foto, produk memakai gambar default.',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPick,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
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
