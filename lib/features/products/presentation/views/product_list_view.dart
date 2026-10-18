import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../settings/domain/store_settings.dart';
import '../../../settings/settings_providers.dart';
import '../../../stock/presentation/views/stock_opname_dialog.dart';
import '../../../reports/domain/demo_catalog.dart';
import '../../domain/entities/product.dart';
import '../../domain/services/bundle_rules.dart';
import '../../domain/services/inventory_summary.dart';
import '../../domain/services/price_suggestion.dart';
import '../../product_providers.dart';
import '../viewmodels/product_view_models.dart';

class ProductListView extends ConsumerWidget {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(productFilterProvider);
    final reorder = ref.watch(reorderProductsProvider).value ?? const <Product>[];
    final mode = ref.watch(productViewModeProvider);
    final isPhone = context.deviceClass == DeviceClass.phone;
    final showTable = mode == ProductViewMode.table && !isPhone;

    return PageScaffold(
      title: 'Produk & stok',
      subtitle: 'Atur harga, stok, dan satuan dalam satu tempat.',
      actions: [const _SampleProductsButton(), const _AddButton()],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isPhone) ...[
            _ProductKpis(reorder: reorder),
            const SizedBox(height: AppSpacing.xl),
          ],
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  spacing: AppSpacing.md,
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
                    if (!isPhone)
                      SegmentedButton<ProductViewMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ProductViewMode.cards,
                            icon: Icon(Icons.grid_view_rounded),
                            label: Text('Kartu'),
                            tooltip: 'Tampilan kartu',
                          ),
                          ButtonSegment(
                            value: ProductViewMode.table,
                            icon: Icon(Icons.table_chart_outlined),
                            label: Text('Tabel'),
                            tooltip: 'Tampilan tabel',
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (s) => ref.read(productViewModeProvider.notifier).set(s.first),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const _FilterBar(),
              ],
            ),
          ),
          if (reorder.isNotEmpty) _RestockBanner(products: reorder, active: filter.restockOnly),
          ref
              .watch(filteredProductsProvider)
              .when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: Center(child: Text('$e')),
                ),
                data: (products) => products.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                        child: EmptyState(icon: Icons.inventory_2_outlined, message: 'Tidak ada produk'),
                      )
                    : showTable
                    ? _ProductTable(products: products)
                    : _ProductGrid(products: products),
              ),
        ],
      ),
    );
  }
}

/// Kartu angka ringkas: jumlah produk aktif, nilai persediaan, dan yang perlu restok.
class _ProductKpis extends ConsumerWidget {
  const _ProductKpis({required this.reorder});

  final List<Product> reorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final active = products.where((p) => p.active).length;
    final bundles = products.where((p) => p.isBundle).length;
    final summary = ref.watch(inventorySummaryProvider);

    return KpiRow(
      children: [
        KpiTile(
          label: 'Produk aktif',
          value: '$active',
          hint: '$bundles paket bundle tersedia',
          icon: Icons.inventory_2_outlined,
          width: null,
        ),
        KpiTile(
          label: 'Nilai persediaan',
          value: summary == null ? '—' : formatRupiah(summary.totalValue),
          hint: 'Berdasarkan harga modal',
          icon: Icons.account_balance_wallet_outlined,
          width: null,
        ),
        KpiTile(
          label: 'Perlu restok',
          value: '${reorder.length} produk',
          hint: 'Di bawah stok minimum',
          icon: Icons.warning_amber_rounded,
          width: null,
        ),
      ],
    );
  }
}

/// Tombol tambah: produk biasa atau bundling.
class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
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
      builder: (context, controller, _) => FilledButton.icon(
        onPressed: () => controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Tambah produk'),
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
    final tokens = context.tokens;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpacing.sm,
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
              avatar: Icon(Icons.warning_amber_rounded, color: tokens.warning),
              label: const Text('Perlu restock'),
              selected: true,
              onDeleted: () => vm.setStock(StockFilter.all),
            ),
          SizedBox(height: 24, child: VerticalDivider(color: tokens.line)),
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
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
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
  StockLevel.safe => context.tokens.success,
  StockLevel.low => context.tokens.warning,
  StockLevel.out => context.tokens.danger,
  StockLevel.untracked => context.tokens.muted,
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

/// Lencana indikator stok (aman / menipis / habis).
class _StockIndicator extends StatelessWidget {
  const _StockIndicator({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final level = StockLevel.of(product);
    final tone = switch (level) {
      StockLevel.safe => BadgeTone.success,
      StockLevel.low => BadgeTone.warning,
      StockLevel.out => BadgeTone.danger,
      StockLevel.untracked => BadgeTone.neutral,
    };
    return StatusBadge(level.label, tone: tone);
  }
}

/// Daftar produk: kartu di HP dan layar sempit, dibungkus sesuai lebar.
class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.md;
        final columns = (constraints.maxWidth / 560).ceil().clamp(1, 4);
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final p in products) SizedBox(width: width, child: _ProductCard(product: p))],
        );
      },
    );
  }
}

/// Tabel produk: satu baris per produk + baris total.
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
    final theme = Theme.of(context);
    final bold = theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);

    int unitCost(Product p) => p.isBundle
        ? BundleRules.cost(p.bundleItems, (id) => InventorySummary.unitCost(costs[id]))
        : InventorySummary.unitCost(costs[p.id]);

    Widget money(int v, {TextStyle? style}) => Text(v > 0 ? formatRupiah(v) : '-', style: style);
    Widget costCell(int Function() v) => costsLoading ? const _LoadingValue() : money(v());

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (costsLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          AppDataTable(
            columns: const [
              'Produk',
              'Keterangan',
              'Harga modal',
              'Harga satuan',
              'Harga karton',
              'Stok',
              'Nilai barang',
              'Status',
              'Aktif',
            ],
            flex: const [3, 3, 2, 2, 2, 2, 2, 2, 1],
            emptyLabel: 'Tidak ada produk',
            rows: [
              for (final p in products)
                [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: [
                      if (p.isBundle) Icon(Icons.redeem_outlined, size: 16, color: theme.colorScheme.primary),
                      Flexible(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: p.active ? context.tokens.ink : context.tokens.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Remarks(product: p),
                  costCell(() => unitCost(p)),
                  _SellPrice(product: p),
                  money(_carton(p)?.price ?? 0),
                  Text(
                    !p.trackStock ? '-' : '${formatNumber(p.stock)} ${p.unit}',
                    style: TextStyle(color: p.isBundle ? context.tokens.muted : null),
                  ),
                  p.isBundle
                      ? const Text('-')
                      : costCell(() => InventorySummary.valueOf(p, costs[p.id])),
                  _StockIndicator(product: p),
                  _ActiveSwitch(product: p),
                ],
              if (summary != null)
                [
                  Text('Total (${products.length} baris)', style: bold),
                  const Text(''),
                  const Text(''),
                  const Text(''),
                  const Text(''),
                  Text(formatNumber(summary.totalStock), style: bold),
                  costsLoading ? const _LoadingValue() : Text(formatRupiah(summary.totalValue), style: bold),
                  const Text(''),
                  const Text(''),
                ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Harga jual + tanda bila di bawah saran harga (HPP rata-rata + margin) atau di bawah modal.
class _SellPrice extends ConsumerWidget {
  const _SellPrice({required this.product, this.style});

  final Product product;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = product;
    final costs = ref.watch(productUnitCostsProvider);
    final settings = ref.watch(storeSettingsProvider).value ?? const StoreSettings();
    final cost = p.isBundle
        ? BundleRules.cost(p.bundleItems, (id) => InventorySummary.unitCost(costs[id]))
        : InventorySummary.unitCost(costs[p.id]);
    final suggested = settings.suggestPrice(cost);
    final text = Text(p.sellPrice > 0 ? formatRupiah(p.sellPrice) : '-', style: style);
    if (suggested <= 0 || p.sellPrice <= 0 || p.sellPrice >= suggested) return text;

    final tokens = context.tokens;
    final belowCost = p.sellPrice < cost;
    return Tooltip(
      message: belowCost
          ? 'Di bawah modal ${formatRupiah(cost)}'
          : 'Margin ${PriceSuggestion.marginOf(p.sellPrice, cost)}% · saran ${formatRupiah(suggested)}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Flexible(child: text),
          Icon(
            belowCost ? Icons.error_outline : Icons.trending_down,
            size: 16,
            color: belowCost ? tokens.danger : tokens.warning,
          ),
        ],
      ),
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
      return Text(
        'Isi: ${BundleRules.contentsLabel(p.bundleItems)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    final packs = p.packsBySize;
    if (packs.isEmpty) {
      return Text('Satuan (${p.unit})', style: Theme.of(context).textTheme.bodySmall);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [for (final pack in packs) _Badge(pack.label(p.unit))],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tokens.primaryTint,
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
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

/// Banner kuning yang selalu terlihat saat ada produk di bawah stok minimum.
class _RestockBanner extends ConsumerWidget {
  const _RestockBanner({required this.products, required this.active});

  final List<Product> products;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final out = products.where((p) => p.isOutOfStock).length;
    return SectionCard(
      highlight: false,
      child: Row(
        spacing: AppSpacing.lg,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tokens.warningTint, shape: BoxShape.circle),
            child: Icon(Icons.warning_amber_rounded, color: tokens.warning),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  '${products.length} produk perlu diisi ulang',
                  style: theme.textTheme.titleSmall?.copyWith(color: tokens.warning),
                ),
                Text(
                  [
                    if (out > 0) '$out habis',
                    products.take(3).map((p) => p.name).join(', ') + (products.length > 3 ? ', …' : ''),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => ref.read(productFilterProvider.notifier).toggleRestock(),
                child: Text(active ? 'Tampilkan semua' : 'Lihat daftar'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/owner/stock-in'),
                icon: const Icon(Icons.add_shopping_cart, size: 18),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final p = product;
    final low = p.active && p.needsReorder;
    final meta = [
      if (p.isBundle) 'isi: ${BundleRules.contentsLabel(p.bundleItems)}',
      if (p.hasWholesale) 'grosir ${formatRupiah(p.wholesalePrice)} (≥${p.wholesaleMinQty})',
      for (final pack in p.packsBySize) '${ProductPack.canonicalName(pack.name)} ${formatRupiah(pack.price)}',
      if (p.category.isNotEmpty && !p.isBundle) p.category,
      if (!p.active) 'nonaktif',
    ].join(' · ');

    return Opacity(
      opacity: p.active ? 1 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: low ? tokens.danger : tokens.line, width: low ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => context.go('/owner/products/${p.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.sm,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.md,
                  children: [
                    ProductImageView(
                      imageBase64: p.imageBase64,
                      fallbackIcon: low
                          ? Icons.priority_high
                          : (p.isBundle ? Icons.redeem_outlined : categoryIcon(p.category)),
                      highlight: low,
                      size: 44,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.xs,
                        children: [
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            [
                              if (p.sku.isNotEmpty) p.sku,
                              p.trackStock ? '${formatNumber(p.stock)} ${p.unit}' : 'tanpa stok',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                          ),
                          _SellPrice(product: p, style: theme.textTheme.titleMedium),
                        ],
                      ),
                    ),
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
                  ],
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                _StockBar(product: p),
                if (low || p.isBundle)
                  Row(
                    spacing: AppSpacing.sm,
                    children: [
                      if (low)
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => context.go('/owner/stock-in'),
                          child: const Text('Restock'),
                        ),
                      if (p.isBundle)
                        Tooltip(
                          message: p.active ? 'Tampil di katalog pelanggan' : 'Disembunyikan dari katalog',
                          child: _ActiveSwitch(product: p),
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
    final tokens = context.tokens;
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
      spacing: AppSpacing.xs,
      children: [
        Text(
          label,
          style: text.labelMedium?.copyWith(
            color: low ? tokens.danger : null,
            fontWeight: low ? FontWeight.w700 : null,
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: LinearProgressIndicator(
            value: (p.stock / target).clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: tokens.line,
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
    return OutlinedButton.icon(
      icon: busy
          ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.coffee_outlined, size: 18),
      label: const Text('Produk contoh'),
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
