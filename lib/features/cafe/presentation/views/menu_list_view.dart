import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../products/product_providers.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe_rules.dart';
import '../cafe_view_models.dart';

/// Daftar menu POS kopi dengan HPP per porsi dari resep dan marginnya.
class MenuListView extends ConsumerWidget {
  const MenuListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(recipesProvider).value ?? const {};
    final ingredients = ref.watch(ingredientMapProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Menu & resep')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cafe/menu/new'),
        icon: const Icon(Icons.add),
        label: const Text('Menu'),
      ),
      body: AsyncValueView(
        value: ref.watch(productsProvider),
        data: (menus) {
          if (menus.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              message: 'Belum ada menu.\nTambahkan menu dan resepnya agar stok bahan terpotong otomatis saat terjual.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final m in menus)
                Builder(builder: (context) {
                  final recipe = recipes[m.id];
                  final cost = CafeRules.menuCost(recipe, ingredients);
                  final margin = m.sellPrice == 0 ? 0 : ((m.sellPrice - cost) / m.sellPrice * 100).round();
                  return ListTile(
                    leading: ProductImageView(imageBase64: m.imageBase64, fallbackIcon: Icons.local_cafe_outlined, size: 48),
                    title: Text(m.name, style: m.active ? null : TextStyle(color: Theme.of(context).disabledColor)),
                    subtitle: Text(
                      [
                        if (m.category.isNotEmpty) m.category,
                        recipe == null || recipe.isEmpty ? 'Tanpa resep' : '${recipe.lines.length} bahan',
                        if (cost > 0) 'HPP ${formatRupiah(cost)} · margin $margin%',
                        if (!m.active) 'Nonaktif',
                      ].join(' · '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatRupiah(m.sellPrice), style: text.titleSmall),
                        Switch(
                          value: m.active,
                          onChanged: (v) => ref.read(cafeActionsViewModelProvider.notifier).setMenuActive(m, v),
                        ),
                      ],
                    ),
                    onTap: () => context.go('/cafe/menu/${m.id}'),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
