import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/feedback.dart';
import '../../domain/entities/product.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';

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
  late final _category = TextEditingController(text: widget.product?.category);
  late final _unit = TextEditingController(text: widget.product?.unit ?? 'pcs');
  late final _buyPrice = TextEditingController(text: _num(widget.cost?.buyPrice));
  late final _sellPrice = TextEditingController(text: _num(widget.product?.sellPrice));
  late final _wholesalePrice = TextEditingController(text: _num(widget.product?.wholesalePrice));
  late final _wholesaleMin = TextEditingController(text: _num(widget.product?.wholesaleMinQty));
  late final _minStock = TextEditingController(text: _num(widget.product?.minStock));
  late bool _trackStock = widget.product?.trackStock ?? true;
  late bool _active = widget.product?.active ?? true;

  static String _num(int? v) => v == null || v == 0 ? '' : '$v';

  @override
  void dispose() {
    for (final c in [_name, _sku, _barcode, _category, _unit, _buyPrice, _sellPrice, _wholesalePrice, _wholesaleMin, _minStock]) {
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
      category: _category.text.trim(),
      unit: _unit.text.trim().isEmpty ? 'pcs' : _unit.text.trim(),
      sellPrice: parseRupiah(_sellPrice.text),
      wholesalePrice: parseRupiah(_wholesalePrice.text),
      wholesaleMinQty: parseRupiah(_wholesaleMin.text),
      minStock: parseRupiah(_minStock.text),
      trackStock: _trackStock,
      active: _active,
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
                    field(_name, 'Nama produk', required: true),
                    Row(spacing: 12, children: [
                      Expanded(child: field(_sku, 'SKU')),
                      Expanded(child: field(_barcode, 'Barcode')),
                    ]),
                    Row(spacing: 12, children: [
                      Expanded(child: field(_category, 'Kategori')),
                      Expanded(child: field(_unit, 'Satuan')),
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
                      onPressed: state.isLoading ? null : _save,
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
