import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../stock/presentation/views/stock_opname_dialog.dart';
import '../../../reports/domain/demo_catalog.dart';
import '../../domain/entities/product.dart';
import '../viewmodels/product_view_models.dart';

class ProductListView extends ConsumerWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productFilterProvider);
    final reorder = ref.watch(reorderProductsProvider).value ?? const <Product>[];
    final categories = ref.watch(productCategoriesProvider);
    final filterVm = ref.read(productFilterProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: const Text('Produk'),
        actions: const [_SampleProductsButton(), SizedBox(width: 8)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/owner/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Produk'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                if (reorder.isNotEmpty) _RestockBanner(products: reorder, active: filter.restockOnly),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Cari nama, SKU, atau barcode',
                  ),
                  onChanged: ref.read(productSearchProvider.notifier).setQuery,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      FilterChip(
                        avatar: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
                        label: Text('Perlu restock (${reorder.length})'),
                        selected: filter.restockOnly,
                        onSelected: (_) => filterVm.toggleRestock(),
                      ),
                      ChoiceChip(
                        label: const Text('Semua kategori'),
                        selected: filter.category == null,
                        onSelected: (_) => filterVm.setCategory(null),
                      ),
                      for (final c in categories)
                        ChoiceChip(
                          avatar: Icon(categoryIcon(c), size: 18),
                          label: Text(c),
                          selected: filter.category == c,
                          onSelected: (_) => filterVm.setCategory(filter.category == c ? null : c),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          ref.watch(filteredProductsProvider).when(
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(child: Center(child: Text('$e'))),
                data: (products) => products.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(icon: Icons.inventory_2_outlined, message: 'Tidak ada produk'),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverGrid.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 560,
                            mainAxisExtent: 132,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, i) => _ProductCard(product: products[i]),
                        ),
                      ),
              ),
        ],
      ),
    );
  }
}

IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('kopi')) return Icons.coffee_outlined;
  if (c.contains('susu') || c.contains('krimer')) return Icons.local_drink_outlined;
  if (c.contains('sirup')) return Icons.liquor_outlined;
  if (c.contains('teh')) return Icons.emoji_food_beverage_outlined;
  if (c.contains('bubuk')) return Icons.blender_outlined;
  if (c.contains('pemanis') || c.contains('gula')) return Icons.cookie_outlined;
  if (c.contains('kemasan')) return Icons.takeout_dining_outlined;
  if (c.contains('makan')) return Icons.restaurant_outlined;
  return Icons.inventory_2_outlined;
}

/// Banner merah yang selalu terlihat saat ada produk di bawah stok minimum.
class _RestockBanner extends ConsumerWidget {
  const _RestockBanner({required this.products, required this.active});

  final List<Product> products;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final out = products.where((p) => p.isOutOfStock).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.error, width: 1.5),
      ),
      child: Row(
        spacing: 16,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.error,
            child: Icon(Icons.notification_important, color: scheme.onError),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  '${products.length} produk perlu restock',
                  style: text.titleMedium?.copyWith(color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (out > 0) '$out habis',
                    products.take(3).map((p) => p.name).join(', ') + (products.length > 3 ? ', …' : ''),
                  ].join(' · '),
                  style: text.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: scheme.onErrorContainer),
                onPressed: () => ref.read(productFilterProvider.notifier).toggleRestock(),
                child: Text(active ? 'Tampilkan semua' : 'Lihat daftar'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                onPressed: () => context.go('/owner/stock-in'),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Restock sekarang'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = product;
    final low = p.active && p.needsReorder;

    return Opacity(
      opacity: p.active ? 1 : 0.55,
      child: Card(
        margin: EdgeInsets.zero,
        color: low ? scheme.errorContainer.withValues(alpha: 0.35) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: low ? scheme.error : scheme.outlineVariant, width: low ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/owner/products/${p.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 14,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProductImageView(
                      imageBase64: p.imageBase64,
                      fallbackIcon: low ? Icons.priority_high : categoryIcon(p.category),
                      highlight: low,
                      size: 64,
                    ),
                    // Foto menutupi tanda restock, jadi tampilkan lencana kecil.
                    if (low && p.hasImage)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: scheme.error,
                          child: Icon(Icons.priority_high, size: 14, color: scheme.onError),
                        ),
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(p.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [
                          formatRupiah(p.sellPrice),
                          if (p.hasWholesale) 'grosir ${formatRupiah(p.wholesalePrice)} (≥${p.wholesaleMinQty})',
                          for (final pack in p.packsBySize) '${pack.name} ${pack.contents}: ${formatRupiah(pack.price)}',
                          if (p.category.isNotEmpty) p.category,
                          if (!p.active) 'nonaktif',
                        ].join(' · '),
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      _StockBar(product: p),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'edit') context.go('/owner/products/${p.id}');
                        if (value == 'opname') StockOpnameDialog.show(context, p);
                        if (value == 'restock') context.go('/owner/stock-in');
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                        if (p.trackStock) const PopupMenuItem(value: 'restock', child: Text('Restock (stok masuk)')),
                        if (p.trackStock) const PopupMenuItem(value: 'opname', child: Text('Stock opname')),
                      ],
                    ),
                    if (low)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.go('/owner/stock-in'),
                        child: const Text('Restock'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bar stok terhadap stok minimum; merah saat perlu restock.
class _StockBar extends StatelessWidget {
  const _StockBar({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (!p.trackStock) return Text('Tanpa stok (jasa)', style: text.labelMedium);

    final low = p.needsReorder;
    final target = (p.minStock * 3).clamp(1, 1 << 30);
    final color = p.isOutOfStock ? scheme.error : (low ? scheme.error : scheme.primary);
    final label = p.isOutOfStock
        ? 'HABIS · min ${p.minStock}'
        : low
            ? 'Stok ${p.stock} ${p.unit} · min ${p.minStock} · PERLU RESTOCK'
            : 'Stok ${p.stock} ${p.unit}${p.minStock > 0 ? ' · min ${p.minStock}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(label, style: text.labelMedium?.copyWith(color: low ? scheme.error : null, fontWeight: low ? FontWeight.w700 : null)),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (p.stock / target).clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

/// Menambahkan katalog contoh distributor cafe ke produk asli (sekali).
class _SampleProductsButton extends ConsumerWidget {
  const _SampleProductsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(sampleProductsViewModelProvider).isLoading;
    return TextButton.icon(
      icon: busy
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.coffee_outlined),
      label: const Text('Produk contoh (cafe)'),
      onPressed: busy
          ? null
          : () async {
              final ok = await confirm(
                context,
                title: 'Tambah / perbarui produk contoh?',
                message: '${DemoCatalog.products.length} produk distributor cafe dalam 8 kategori, dengan harga per karton / ball / pouch. '
                    'Produk contoh yang belum ada ditambahkan beserta stok awal (Stok Masuk). '
                    'Yang sudah ada hanya diperbarui kategori & kemasannya; harga tidak diubah.',
              );
              if (!ok || !context.mounted) return;
              final result = await ref.read(sampleProductsViewModelProvider.notifier).addCafeSamples();
              if (!context.mounted) return;
              showMessage(
                context,
                result == null
                    ? '${ref.read(sampleProductsViewModelProvider).error}'
                    : '${result.$1} produk ditambahkan, ${result.$2} diperbarui',
                isError: result == null,
              );
            },
    );
  }
}
