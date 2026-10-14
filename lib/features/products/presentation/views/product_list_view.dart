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
import '../../domain/services/bundle_rules.dart';
import '../../domain/services/inventory_summary.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';

class ProductListView extends ConsumerWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productFilterProvider);
    final reorder = ref.watch(reorderProductsProvider).value ?? const <Product>[];
    final mode = ref.watch(productViewModeProvider);
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: const Text('Produk'),
        actions: [if (wide) const _InventoryTotals(), const _SampleProductsButton(), const SizedBox(width: 8)],
      ),
      floatingActionButton: const _AddButton(),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList.list(
              children: [
                if (!wide) const Align(alignment: Alignment.centerRight, child: _InventoryTotals()),
                if (!wide) const SizedBox(height: 8),
                if (reorder.isNotEmpty) _RestockBanner(products: reorder, active: filter.restockOnly),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Cari nama, SKU, atau barcode',
                        ),
                        onChanged: ref.read(productSearchProvider.notifier).setQuery,
                      ),
                    ),
                    SegmentedButton<ProductViewMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ProductViewMode.cards,
                          icon: const Icon(Icons.grid_view_rounded),
                          label: wide ? const Text('Kartu') : null,
                          tooltip: 'Tampilan kartu',
                        ),
                        ButtonSegment(
                          value: ProductViewMode.table,
                          icon: const Icon(Icons.table_chart_outlined),
                          label: wide ? const Text('Tabel') : null,
                          tooltip: 'Tampilan tabel',
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => ref.read(productViewModeProvider.notifier).set(s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _FilterBar(),
                const SizedBox(height: 12),
              ],
            ),
          ),
          ref
              .watch(filteredProductsProvider)
              .when(
                loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                error: (e, _) => SliverFillRemaining(child: Center(child: Text('$e'))),
                data: (products) => products.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(icon: Icons.inventory_2_outlined, message: 'Tidak ada produk'),
                      )
                    : mode == ProductViewMode.table
                    ? SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        sliver: SliverToBoxAdapter(child: _ProductTable(products: products)),
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

/// Tombol tambah: produk biasa atau bundling.
class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, -8),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.inventory_2_outlined),
          onPressed: () => context.go('/owner/products/new'),
          child: const Text('Produk baru'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.redeem_outlined),
          onPressed: () => context.go('/owner/products/new-bundle'),
          child: const Text('Bundling baru'),
        ),
      ],
      builder: (context, controller, _) => FloatingActionButton.extended(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }
}

/// Total stok & nilai barang (stok × modal) seluruh produk, di kanan atas.
class _InventoryTotals extends ConsumerWidget {
  const _InventoryTotals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(inventorySummaryProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Masih memuat produk / harga modal: tampilkan kotak yang sama dengan indikator loading.
    final loading = summary == null;

    Widget stat(String label, String? value, IconData icon) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
            if (value != null)
              Text(value, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))
            else
              const _LoadingValue(),
          ],
        ),
      ],
    );

    return Tooltip(
      message: loading
          ? 'Menghitung total stok & nilai barang…'
          : '${summary.productCount} produk yang dihitung stoknya. '
                'Nilai barang = stok × harga modal (HPP rata-rata, atau harga beli bila HPP belum ada). '
                'Bundling tidak dihitung karena isinya sudah terhitung.',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            stat('Total stok', loading ? null : formatNumber(summary.totalStock), Icons.inventory_outlined),
            stat(
              'Total nilai barang',
              loading ? null : formatRupiah(summary.totalValue),
              Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pengganti angka selama data masih dimuat.
class _LoadingValue extends StatelessWidget {
  const _LoadingValue();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      const SizedBox.square(dimension: 12, child: CircularProgressIndicator(strokeWidth: 2)),
      Text('Memuat…', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

/// Filter stok (chip berwarna) + jenis, status, kategori, dan urutan.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productFilterProvider);
    final vm = ref.read(productFilterProvider.notifier);
    final categories = ref.watch(productCategoriesProvider);
    final counts = ref.watch(_stockCountsProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: 8,
        children: [
          for (final f in [StockFilter.all, StockFilter.safe, StockFilter.low, StockFilter.out])
            ChoiceChip(
              avatar: f == StockFilter.all ? null : _StockDot(level: _levelOf(f)),
              label: Text(counts[f] == null ? f.label : '${f.label} (${counts[f]})'),
              selected: filter.stock == f,
              onSelected: (_) => vm.setStock(filter.stock == f && f != StockFilter.all ? StockFilter.all : f),
            ),
          if (filter.restockOnly)
            InputChip(
              avatar: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
              label: const Text('Perlu restock'),
              selected: true,
              onDeleted: () => vm.setStock(StockFilter.all),
            ),
          const SizedBox(height: 24, child: VerticalDivider()),
          _MenuChip<ProductTypeFilter>(
            icon: Icons.redeem_outlined,
            value: filter.type,
            isDefault: filter.type == ProductTypeFilter.all,
            options: ProductTypeFilter.values,
            labelOf: (v) => v.label,
            onSelected: vm.setType,
          ),
          _MenuChip<ActiveFilter>(
            icon: Icons.toggle_on_outlined,
            value: filter.status,
            isDefault: filter.status == ActiveFilter.all,
            options: ActiveFilter.values,
            labelOf: (v) => v.label,
            onSelected: vm.setStatus,
          ),
          _MenuChip<String?>(
            icon: filter.category == null ? Icons.category_outlined : categoryIcon(filter.category!),
            value: filter.category,
            isDefault: filter.category == null,
            options: [null, ...categories],
            labelOf: (v) => v ?? 'Semua kategori',
            onSelected: vm.setCategory,
          ),
          _MenuChip<ProductSort>(
            icon: Icons.sort,
            value: filter.sort,
            isDefault: true,
            options: ProductSort.values,
            labelOf: (v) => 'Urut: ${v.label}',
            onSelected: vm.setSort,
          ),
          if (filter.isFiltered)
            TextButton.icon(
              onPressed: vm.reset,
              icon: const Icon(Icons.filter_alt_off_outlined),
              label: const Text('Reset filter'),
            ),
        ],
      ),
    );
  }

  static StockLevel _levelOf(StockFilter f) => switch (f) {
    StockFilter.low => StockLevel.low,
    StockFilter.out => StockLevel.out,
    _ => StockLevel.safe,
  };
}

/// Jumlah produk per indikator stok (produk biasa saja).
final _stockCountsProvider = Provider<Map<StockFilter, int>>((ref) {
  final products = (ref.watch(productsProvider).value ?? const <Product>[]).where((p) => !p.isBundle);
  return {
    for (final f in [StockFilter.safe, StockFilter.low, StockFilter.out]) f: products.where(f.accepts).length,
  };
});

/// Chip yang membuka menu pilihan.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.value,
    required this.isDefault,
    required this.options,
    required this.labelOf,
    required this.onSelected,
  });

  final IconData icon;
  final T value;
  final bool isDefault;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final o in options)
          MenuItemButton(
            leadingIcon: Icon(o == value ? Icons.check : null, size: 18),
            onPressed: () => onSelected(o),
            child: Text(labelOf(o)),
          ),
      ],
      builder: (context, controller, _) => FilterChip(
        avatar: Icon(icon, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Text(labelOf(value)), const Icon(Icons.arrow_drop_down, size: 18)],
        ),
        selected: !isDefault,
        showCheckmark: false,
        onSelected: (_) => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// Warna indikator stok: hijau aman, kuning menipis, merah habis.
Color stockLevelColor(BuildContext context, StockLevel level) => switch (level) {
  StockLevel.safe => const Color(0xFF2E7D32),
  StockLevel.low => const Color(0xFFF9A825),
  StockLevel.out => Theme.of(context).colorScheme.error,
  StockLevel.untracked => Theme.of(context).colorScheme.outline,
};

class _StockDot extends StatelessWidget {
  const _StockDot({required this.level, this.size = 12});

  final StockLevel level;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: stockLevelColor(context, level), shape: BoxShape.circle),
  );
}

class _StockIndicator extends StatelessWidget {
  const _StockIndicator({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final level = StockLevel.of(product);
    final color = stockLevelColor(context, level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          _StockDot(level: level, size: 10),
          Text(level.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Tampilan seperti Excel: satu baris per produk + baris total.
class _ProductTable extends ConsumerWidget {
  const _ProductTable({required this.products});

  final List<Product> products;

  static ProductPack? _carton(Product p) =>
      p.packs.where((x) => x.isValid && x.name.toLowerCase() == 'karton').firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costs = ref.watch(productUnitCostsProvider);
    final summary = ref.watch(filteredInventorySummaryProvider);
    // Harga modal dibaca terpisah dari produk; selama belum ada, kolom modal & nilai menunggu.
    final costsLoading = !ref.watch(productCostsProvider).hasValue;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bold = text.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    int unitCost(Product p) => p.isBundle
        ? BundleRules.cost(p.bundleItems, (id) => InventorySummary.unitCost(costs[id]))
        : InventorySummary.unitCost(costs[p.id]);

    DataCell money(int v, {TextStyle? style}) => DataCell(Text(v > 0 ? formatRupiah(v) : '-', style: style));
    DataCell costMoney(int Function() v) => costsLoading ? const DataCell(_LoadingValue()) : money(v());

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (costsLoading) const LinearProgressIndicator(minHeight: 3),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                  headingTextStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  columnSpacing: 24,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 60,
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Keterangan')),
                    DataColumn(label: Text('Harga modal'), numeric: true),
                    DataColumn(label: Text('Harga satuan'), numeric: true),
                    DataColumn(label: Text('Harga karton'), numeric: true),
                    DataColumn(label: Text('Jumlah stok'), numeric: true),
                    DataColumn(
                      label: Tooltip(message: 'Jumlah stok × harga modal', child: Text('Nilai barang')),
                      numeric: true,
                    ),
                    DataColumn(label: Text('Indikator stok')),
                    DataColumn(label: Text('Aktif')),
                  ],
                  rows: [
                    for (final p in products)
                      DataRow(
                        color: p.active ? null : WidgetStatePropertyAll(scheme.surfaceContainerLow),
                        onSelectChanged: (_) => context.go('/owner/products/${p.id}'),
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 6,
                                children: [
                                  if (p.isBundle) Icon(Icons.redeem_outlined, size: 18, color: scheme.primary),
                                  Flexible(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: p.active ? null : TextStyle(color: scheme.outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(_Remarks(product: p)),
                          costMoney(() => unitCost(p)),
                          money(p.sellPrice),
                          money(_carton(p)?.price ?? 0),
                          DataCell(
                            Text(
                              !p.trackStock ? '-' : '${formatNumber(p.stock)} ${p.unit}',
                              style: TextStyle(color: p.isBundle ? scheme.onSurfaceVariant : null),
                            ),
                          ),
                          p.isBundle
                              ? const DataCell(
                                  Tooltip(message: 'Bundling: nilai sudah dihitung di produk isinya', child: Text('-')),
                                )
                              : costMoney(() => InventorySummary.valueOf(p, costs[p.id])),
                          DataCell(_StockIndicator(product: p)),
                          DataCell(_ActiveSwitch(product: p)),
                        ],
                      ),
                    if (summary != null)
                      DataRow(
                        color: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                        cells: [
                          DataCell(Text('Total (${products.length} baris)', style: bold)),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(Text(formatNumber(summary.totalStock), style: bold)),
                          costsLoading
                              ? const DataCell(_LoadingValue())
                              : DataCell(Text(formatRupiah(summary.totalValue), style: bold)),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nama produk + keterangan isi kemasan di sebelahnya (tampilan kartu).
class _NameWithPacks extends StatelessWidget {
  const _NameWithPacks({required this.product, this.style});

  final Product product;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final label = product.packsLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        Flexible(
          child: Text(product.name, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (label.isNotEmpty) Flexible(child: _Badge(label)),
      ],
    );
  }
}

/// Kolom "Keterangan" di tabel: isi tiap kemasan, atau isi paket untuk bundling.
class _Remarks extends StatelessWidget {
  const _Remarks({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p.isBundle) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Text(
          'Isi: ${BundleRules.contentsLabel(p.bundleItems)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final packs = p.packsBySize;
    if (packs.isEmpty) {
      return Text('Satuan (${p.unit})', style: Theme.of(context).textTheme.bodySmall);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [for (final pack in packs) _Badge(pack.label(p.unit))],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Aktif / nonaktif langsung dari daftar. Untuk bundling = tampil / tidak di katalog pelanggan.
class _ActiveSwitch extends ConsumerWidget {
  const _ActiveSwitch({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Switch(
      value: product.active,
      onChanged: (v) async {
        final ok = await ref.read(productFormViewModelProvider.notifier).setActive(product, v);
        if (!context.mounted) return;
        showMessage(
          context,
          ok
              ? '${product.name} ${v ? 'diaktifkan' : 'dinonaktifkan'}'
                    '${product.isBundle ? (v ? ' — tampil di katalog' : ' — disembunyikan dari katalog') : ''}'
              : '${ref.read(productFormViewModelProvider).error}',
          isError: !ok,
        );
      },
    );
  }
}

IconData categoryIcon(String category) {
  final c = category.toLowerCase();
  if (c.contains('bundling') || c.contains('paket')) return Icons.redeem_outlined;
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
                      fallbackIcon: low
                          ? Icons.priority_high
                          : (p.isBundle ? Icons.redeem_outlined : categoryIcon(p.category)),
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
                      _NameWithPacks(product: p, style: text.titleMedium),
                      Text(
                        [
                          if (p.isBundle) 'BUNDLING',
                          formatRupiah(p.sellPrice),
                          if (p.isBundle) 'isi: ${BundleRules.contentsLabel(p.bundleItems)}',
                          if (p.hasWholesale) 'grosir ${formatRupiah(p.wholesalePrice)} (≥${p.wholesaleMinQty})',
                          for (final pack in p.packsBySize)
                            '${ProductPack.canonicalName(pack.name)} ${formatRupiah(pack.price)}',
                          if (p.category.isNotEmpty && !p.isBundle) p.category,
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
                        if (p.trackStock && !p.isBundle)
                          const PopupMenuItem(value: 'restock', child: Text('Restock (stok masuk)')),
                        if (p.trackStock && !p.isBundle)
                          const PopupMenuItem(value: 'opname', child: Text('Stock opname')),
                      ],
                    ),
                    if (p.isBundle)
                      Tooltip(
                        message: p.active ? 'Tampil di katalog pelanggan' : 'Disembunyikan dari katalog',
                        child: _ActiveSwitch(product: p),
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
    if (p.isBundle) {
      final level = StockLevel.of(p);
      return Row(
        spacing: 6,
        children: [
          _StockDot(level: level, size: 10),
          Text(
            [
              p.trackStock ? 'Bisa dibuat ${p.stock} paket' : 'Tanpa batas stok',
              p.active ? 'tampil di katalog' : 'disembunyikan',
            ].join(' · '),
            style: text.labelMedium,
          ),
        ],
      );
    }
    if (!p.trackStock) return Text('Tanpa stok (jasa)', style: text.labelMedium);

    final low = p.needsReorder;
    final target = (p.minStock * 3).clamp(1, 1 << 30);
    final color = stockLevelColor(context, StockLevel.of(p));
    final label = p.isOutOfStock
        ? 'HABIS · min ${p.minStock}'
        : low
        ? 'Stok ${p.stock} ${p.unit} · min ${p.minStock} · PERLU RESTOCK'
        : 'Stok ${p.stock} ${p.unit}${p.minStock > 0 ? ' · min ${p.minStock}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(color: low ? scheme.error : null, fontWeight: low ? FontWeight.w700 : null),
        ),
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
                message:
                    '${DemoCatalog.products.length} produk distributor cafe dalam 8 kategori, dengan harga per karton / bal. '
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
