import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/products/domain/entities/product.dart';
import '../../features/products/product_providers.dart';
import '../utils/money.dart';

/// Kolom pencarian produk aktif (nama, SKU, atau barcode).
class ProductPicker extends ConsumerWidget {
  const ProductPicker({super.key, required this.onSelected, this.label = 'Cari produk', this.includeBundles = true});

  final ValueChanged<Product> onSelected;
  final String label;

  /// false untuk stok masuk & isi bundling: bundling tidak punya stok sendiri.
  final bool includeBundles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(activeProductsProvider).value ?? const <Product>[];
    final products = includeBundles ? all : all.where((p) => !p.isBundle).toList();
    return Autocomplete<Product>(
      displayStringForOption: (p) => p.name,
      optionsBuilder: (value) =>
          value.text.isEmpty ? const Iterable<Product>.empty() : products.where((p) => p.matches(value.text)).take(20),
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.search)),
        onSubmitted: (_) {
          // Scan barcode: cocok persis langsung dipilih.
          final match = products.where((p) => p.barcode.isNotEmpty && p.barcode == controller.text.trim());
          if (match.isNotEmpty) {
            onSelected(match.first);
            controller.clear();
          } else {
            onSubmit();
          }
        },
      ),
      optionsViewBuilder: (context, onSelect, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320, maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in options)
                  ListTile(
                    dense: true,
                    title: Text(p.isBundle ? '${p.name} (bundling)' : p.name),
                    subtitle: Text('${formatRupiah(p.sellPrice)} · ${p.trackStock ? 'stok ${p.stock}' : 'tanpa stok'}'),
                    onTap: () => onSelect(p),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
