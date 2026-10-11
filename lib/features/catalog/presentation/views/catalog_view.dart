import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../pricing/pricing_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/viewmodels/product_view_models.dart';
import '../../../products/product_providers.dart';
import '../viewmodels/customer_cart_view_model.dart';
import '../../../../core/router/app_shell.dart';

class CatalogView extends ConsumerWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(productSearchProvider);
    final uid = ref.watch(currentUserProvider).uid;
    final cart = ref.watch(customerCartViewModelProvider(uid));
    final promos = ref.watch(catalogPromosProvider).value ?? const [];
    final now = ref.watch(clockProvider)();

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), 
        title: const Text('Katalog'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => context.go('/shop/cart'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari produk'),
              onChanged: ref.read(productSearchProvider.notifier).setQuery,
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: ref.watch(activeProductsProvider),
              data: (all) {
                final products = all.where((p) => p.matches(query)).toList();
                if (products.isEmpty) return const EmptyState(icon: Icons.search_off, message: 'Produk tidak ditemukan');
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 250,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.promoPrice});

  final Product product;
  final int? promoPrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final out = product.isOutOfStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            const SizedBox(height: 4),
            if (promoPrice != null) ...[
              Text(formatRupiah(product.sellPrice),
                  style: text.bodySmall?.copyWith(decoration: TextDecoration.lineThrough)),
              Text(formatRupiah(promoPrice!), style: text.titleMedium?.copyWith(color: scheme.primary)),
            ] else
              Text(formatRupiah(product.sellPrice), style: text.titleMedium),
            Text('per ${product.unit}', style: text.bodySmall),
            if (product.hasWholesale)
              Text('Grosir ≥${product.wholesaleMinQty}: ${formatRupiah(product.wholesalePrice)}', style: text.bodySmall),
            for (final pack in product.packsBySize)
              Text('${pack.name[0].toUpperCase()}${pack.name.substring(1)} isi ${pack.contents}: ${formatRupiah(pack.price)}',
                  style: text.bodySmall?.copyWith(color: scheme.primary)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    out ? 'Habis' : (product.trackStock && product.stock <= product.minStock ? 'Stok terbatas' : 'Tersedia'),
                    style: text.bodySmall?.copyWith(color: out ? scheme.error : null),
                  ),
                ),
                for (final pack in product.packsBySize.reversed.take(2))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: out ? null : () => _add(context, ref, qty: pack.contents),
                      child: Text('+${pack.name}'),
                    ),
                  ),
                IconButton.filledTonal(
                  tooltip: '+1 ${product.unit}',
                  icon: const Icon(Icons.add_shopping_cart),
                  onPressed: out ? null : () => _add(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {int qty = 1}) async {
    final uid = ref.read(currentUserProvider).uid;
    final message = ref.read(customerCartViewModelProvider(uid).notifier).add(product, qty);
    showMessage(context, message ?? '$qty ${product.unit} ${product.name} masuk keranjang', isError: message != null);
  }
}
