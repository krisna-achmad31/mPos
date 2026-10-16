import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../pricing/pricing_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/domain/services/bundle_rules.dart';
import '../../../products/presentation/viewmodels/product_view_models.dart';
import '../../../products/presentation/views/product_list_view.dart' show categoryIcon;
import '../../../products/product_providers.dart';
import '../viewmodels/customer_cart_view_model.dart';

/// Katalog pelanggan (padanan frame `29 · Pelanggan / Katalog`,
/// `47 · Mobile / Katalog pelanggan`, `86 · Tablet / Katalog`).
class CatalogView extends ConsumerStatefulWidget {
  const CatalogView({super.key});

  @override
  ConsumerState<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends ConsumerState<CatalogView> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(productSearchProvider);
    final uid = ref.watch(currentUserProvider).uid;
    final cart = ref.watch(customerCartViewModelProvider(uid));
    final promos = ref.watch(catalogPromosProvider).value ?? const [];
    final now = ref.watch(clockProvider)();
    final categories = ref.watch(productCategoriesProvider);
    final isPhone = context.deviceClass == DeviceClass.phone;

    return PageScaffold(
      title: 'Katalog',
      subtitle: 'Belanja kebutuhan toko dari distributor Anda.',
      actions: [
        FilledButton.icon(
          onPressed: () => context.go('/shop/cart'),
          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
          label: Text(cart.itemCount > 0 ? 'Keranjang · ${cart.itemCount} item' : 'Keranjang'),
        ),
      ],
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari produk…'),
            onChanged: ref.read(productSearchProvider.notifier).setQuery,
          ),
          const SizedBox(height: AppSpacing.md),
          _CategoryChips(
            categories: categories,
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(activeProductsProvider),
              data: (all) {
                final products = all
                    .where((p) => p.matches(query) && (_category == null || p.category == _category))
                    .toList();
                if (products.isEmpty) {
                  return const EmptyState(icon: Icons.search_off, message: 'Produk tidak ditemukan');
                }
                return GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: isPhone
                      ? const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 388,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        )
                      : const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 388,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                  itemCount: products.length,
                  itemBuilder: (context, i) => _ProductCard(
                    product: products[i],
                    promoPrice: PricingService.catalogPromoPrice(products[i], promos, now, customerId: uid),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris chip filter kategori di bawah kolom pencarian.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.selected, required this.onSelected});

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            label: const Text('Semua produk'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final c in categories)
            ChoiceChip(
              label: Text(c),
              selected: selected == c,
              onSelected: (_) => onSelected(c),
            ),
        ],
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.promoPrice});

  final Product product;
  final int? promoPrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final text = theme.textTheme;
    final primary = theme.colorScheme.primary;
    final out = product.isOutOfStock;
    final limited = product.trackStock && product.stock <= product.minStock;
    final normal = BundleRules.normalPrice(product.bundleItems);
    final saving = product.isBundle ? normal - product.sellPrice : 0;

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Stack(
              children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: ProductImageView(
                    imageBase64: product.imageBase64,
                    fallbackIcon: product.isBundle ? Icons.redeem_outlined : categoryIcon(product.category),
                    borderRadius: AppRadius.control,
                  ),
                ),
                if (product.isBundle)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: StatusBadge(
                      saving > 0 ? 'Hemat ${formatRupiah(saving)}' : 'Bundling',
                      tone: BadgeTone.info,
                      icon: Icons.redeem,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                  Text(
                    product.isBundle
                        ? 'Isi: ${BundleRules.contentsLabel(product.bundleItems)}'
                        : 'per ${product.unit}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                  if (product.isBundle && promoPrice == null && saving > 0) ...[
                    Text(
                      formatRupiah(normal),
                      style: text.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                    ),
                    Text(formatRupiah(product.sellPrice), style: text.titleMedium?.copyWith(color: primary)),
                  ] else if (promoPrice != null) ...[
                    Text(
                      formatRupiah(product.sellPrice),
                      style: text.bodySmall?.copyWith(decoration: TextDecoration.lineThrough),
                    ),
                    Text(formatRupiah(promoPrice!), style: text.titleMedium?.copyWith(color: primary)),
                  ] else
                    Text(formatRupiah(product.sellPrice), style: text.titleMedium),
                  if (product.hasWholesale)
                    Text(
                      'Grosir ≥${product.wholesaleMinQty}: ${formatRupiah(product.wholesalePrice)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  Text(
                    out ? 'Habis' : (limited ? 'Stok terbatas' : 'Tersedia'),
                    style: text.bodySmall?.copyWith(
                      color: out ? tokens.danger : (limited ? tokens.warning : tokens.muted),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final pack in product.packsBySize.reversed.take(2))
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          ),
                          onPressed: out ? null : () => _add(context, ref, qty: pack.contents),
                          child: Text('+${pack.name}'),
                        ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
                        onPressed: out ? null : () => _add(context, ref),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {int qty = 1}) async {
    final uid = ref.read(currentUserProvider).uid;
    final message = ref.read(customerCartViewModelProvider(uid).notifier).add(product, qty);
    showMessage(context, message ?? '$qty ${product.unit} ${product.name} masuk keranjang', isError: message != null);
  }
}
