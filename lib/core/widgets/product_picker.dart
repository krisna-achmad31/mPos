import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/products/domain/entities/product.dart';
import '../../features/products/product_providers.dart';
import '../theme/app_tokens.dart';
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
      optionsViewBuilder: (context, onSelect, options) {
        final theme = Theme.of(context);
        final tokens = context.tokens;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320, maxWidth: 480),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: tokens.line),
                itemBuilder: (context, index) {
                  final p = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      p.isBundle ? '${p.name} (bundling)' : p.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${formatRupiah(p.sellPrice)} · ${p.trackStock ? 'stok ${p.stock}' : 'tanpa stok'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                    onTap: () => onSelect(p),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
