import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../stock/presentation/views/stock_opname_dialog.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/product_view_models.dart';
import '../../../../core/router/app_shell.dart';

class ProductListView extends ConsumerWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Produk')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/owner/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama, SKU, atau barcode'),
              onChanged: ref.read(productSearchProvider.notifier).setQuery,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(filteredProductsProvider),
              data: (products) => products.isEmpty
                  ? const EmptyState(icon: Icons.inventory_2_outlined, message: 'Belum ada produk')
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => _ProductTile(product: products[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stockText = product.trackStock ? 'Stok ${product.stock} ${product.unit}' : 'Tanpa stok';
    return ListTile(
      enabled: product.active,
      title: Text(product.name),
      subtitle: Text([
        formatRupiah(product.sellPrice),
        if (product.hasWholesale) 'grosir ${formatRupiah(product.wholesalePrice)} (≥${product.wholesaleMinQty})',
        stockText,
        if (!product.active) 'nonaktif',
      ].join(' · ')),
      leading: product.needsReorder
          ? Tooltip(
              message: 'Stok ≤ minimum (${product.minStock}), perlu order ulang',
              child: Icon(Icons.warning_amber_rounded, color: scheme.error),
            )
          : const Icon(Icons.inventory_2_outlined),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') context.go('/owner/products/${product.id}');
          if (value == 'opname') StockOpnameDialog.show(context, product);
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Ubah')),
          if (product.trackStock) const PopupMenuItem(value: 'opname', child: Text('Stock opname')),
        ],
      ),
      onTap: () => context.go('/owner/products/${product.id}'),
    );
  }
}
