import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../../products/product_providers.dart';
import '../viewmodels/customer_cart_view_model.dart';

class CartView extends ConsumerWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerCartViewModelProvider);
    final vm = ref.read(customerCartViewModelProvider.notifier);
    final products = {for (final p in ref.watch(activeProductsProvider).value ?? const []) p.id: p};
    final user = ref.watch(currentUserProvider);
    ref.listen(customerCartViewModelProvider.select((s) => s.submission), (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    void notify(String? message) {
      if (message != null) showMessage(context, message, isError: true);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Keranjang'), leading: BackButton(onPressed: () => context.go('/shop'))),
      body: state.lines.isEmpty
          ? const EmptyState(icon: Icons.shopping_cart_outlined, message: 'Keranjang masih kosong')
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (var i = 0; i < state.lines.length; i++)
                  Builder(builder: (context) {
                    final line = state.lines[i];
                    final product = products[line.productId];
                    return ListTile(
                      title: Text(line.name),
                      subtitle: Text('${formatRupiah(line.unitPrice)} / ${line.unit} (${line.priceType.label})'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: product == null ? null : () => notify(vm.setQty(i, line.qty - 1, product)),
                          ),
                          Text('${line.qty}'),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: product == null ? null : () => notify(vm.setQty(i, line.qty + 1, product)),
                          ),
                          SizedBox(width: 100, child: Text(formatRupiah(line.gross), textAlign: TextAlign.end)),
                        ],
                      ),
                    );
                  }),
                const Divider(),
                ListTile(
                  title: const Text('Subtotal'),
                  subtitle: const Text('Diskon (jika ada) muncul di invoice'),
                  trailing: Text(formatRupiah(state.subtotal), style: Theme.of(context).textTheme.titleMedium),
                ),
                ListTile(title: const Text('Kirim ke'), subtitle: Text(user.address.isEmpty ? '-' : user.address)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Catatan untuk penjual'),
                    onChanged: vm.setNote,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: state.submission.isLoading
                        ? null
                        : () async {
                            final ok = await vm.checkout();
                            if (ok && context.mounted) {
                              showMessage(context, 'Pesanan terkirim');
                              context.go('/shop/orders');
                            }
                          },
                    child: const Text('Pesan sekarang'),
                  ),
                ),
              ],
            ),
    );
  }
}
