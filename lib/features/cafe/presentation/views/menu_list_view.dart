import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../domain/cafe_rules.dart';
import '../cafe_view_models.dart';

/// Daftar menu POS kopi dengan HPP per porsi dari resep dan marginnya.
class MenuListView extends ConsumerWidget {
  const MenuListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider).value ?? const {};
    final ingredients = ref.watch(ingredientMapProvider);
    return PageScaffold(
      title: 'Menu & resep',
      subtitle: 'Harga jual dan bahan untuk setiap porsi.',
      workspace: 'POS Kopi',
      actions: [
        FilledButton.icon(
          onPressed: () => context.go('/cafe/menu/new'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Tambah menu'),
        ),
      ],
      child: AsyncValueView(
        value: ref.watch(productsProvider),
        data: (menus) {
          if (menus.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'Belum ada menu.\nTambahkan menu dan resepnya agar stok bahan terpotong otomatis saat terjual.',
              action: FilledButton.icon(
                onPressed: () => context.go('/cafe/menu/new'),
                icon: const Icon(Icons.add),
                label: const Text('Tambah menu'),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final menu in menus)
                _MenuCard(menu: menu, recipe: recipes[menu.id], ingredients: ingredients),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu satu menu: kategori, harga jual, HPP/margin, dan ketersediaannya.
class _MenuCard extends ConsumerWidget {
  const _MenuCard({required this.menu, required this.recipe, required this.ingredients});

  final Product menu;
  final Recipe? recipe;
  final Map<String, Ingredient> ingredients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final cost = CafeRules.menuCost(recipe, ingredients);
    final margin = menu.sellPrice == 0 ? 0 : ((menu.sellPrice - cost) / menu.sellPrice * 100).round();
    final portions = recipe == null || recipe!.isEmpty ? null : recipe!.lines.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: () => context.go('/cafe/menu/${menu.id}'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: tokens.line),
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.lg,
              children: [
                ProductImageView(
                  imageBase64: menu.imageBase64,
                  fallbackIcon: Icons.local_cafe_outlined,
                  size: 56,
                  borderRadius: AppRadius.tile,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              menu.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: menu.active ? tokens.ink : tokens.muted,
                              ),
                            ),
                          ),
                          Switch(
                            value: menu.active,
                            onChanged: (v) => ref.read(cafeActionsViewModelProvider.notifier).setMenuActive(menu, v),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (menu.category.isNotEmpty) StatusBadge(menu.category),
                          if (portions == null)
                            const StatusBadge('Tanpa resep')
                          else
                            StatusBadge('$portions bahan', tone: BadgeTone.info),
                          if (!menu.active) const StatusBadge('Nonaktif', tone: BadgeTone.warning),
                        ],
                      ),
                      Text(
                        formatRupiah(menu.sellPrice),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (cost > 0)
                        Text(
                          'HPP ${formatRupiah(cost)} · margin $margin%',
                          style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
