import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../pricing/pricing_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../../sales/domain/entities/cart_line.dart';
import '../../../sales/domain/services/cart_rules.dart';
import '../../../sales/presentation/widgets/line_text.dart';
import '../viewmodels/customer_cart_view_model.dart';

/// Keranjang pelanggan (padanan frame `30 · Pelanggan / Keranjang`,
/// `64 · Mobile / Keranjang pelanggan`, `87 · Tablet / Keranjang`).
class CartView extends ConsumerWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final cartProvider = customerCartViewModelProvider(user.uid);
    final state = ref.watch(cartProvider);
    final vm = ref.read(cartProvider.notifier);
    final products = {for (final p in ref.watch(activeProductsProvider).value ?? const []) p.id: p};
    // Estimasi promo yang memang boleh dilihat akun ini; harga khusus tetap baru muncul di invoice.
    final promos = PricingService.visiblePromosFor(ref.watch(catalogPromosProvider).value ?? const [], user.uid);
    final estimated = CartRules.applyDiscounts(state.lines,
        customerId: user.uid, discounts: promos, now: ref.watch(clockProvider)());
    final promoTotal = estimated.fold(0, (s, l) => s + l.discountAmount);
    final isWide = context.deviceClass != DeviceClass.phone;
    ref.listen(cartProvider.select((s) => s.submission), (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    void notify(String? message) {
      if (message != null) showMessage(context, message, isError: true);
    }

    Widget itemsCard() => SectionCard(
          title: 'Item pesanan',
          subtitle: '${state.itemCount} item dalam keranjang.',
          trailing: TextButton(onPressed: () => context.go('/shop'), child: const Text('Lanjut belanja')),
          child: isWide
              ? AppDataTable(
                  columns: const ['Produk', 'Jumlah', 'Harga', 'Subtotal'],
                  flex: const [4, 3, 2, 2],
                  emptyLabel: 'Keranjang masih kosong.',
                  rows: [
                    for (var i = 0; i < state.lines.length; i++)
                      [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.lines[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(lineDetail(state.lines[i]), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _LineControls(
                            line: state.lines[i],
                            product: products[state.lines[i].productId],
                            onSetQty: (qty) => notify(vm.setQty(i, qty, products[state.lines[i].productId]!)),
                          ),
                        ),
                        Text(formatRupiah(state.lines[i].unitPrice)),
                        _Subtotal(line: state.lines[i], discount: estimated[i]),
                      ],
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < state.lines.length; i++)
                      _CartItemCard(
                        line: state.lines[i],
                        discount: estimated[i],
                        product: products[state.lines[i].productId],
                        onSetQty: (qty) => notify(vm.setQty(i, qty, products[state.lines[i].productId]!)),
                      ),
                  ],
                ),
        );

    Widget summary() => SectionCard(
          title: 'Ringkasan belanja',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoRow(label: 'Subtotal', value: formatRupiah(state.subtotal)),
              if (promoTotal > 0)
                InfoRow(
                  label: 'Promo untuk Anda',
                  value: '−${formatRupiah(promoTotal)}',
                  valueColor: Theme.of(context).colorScheme.primary,
                ),
              InfoRow(
                label: promoTotal > 0 ? 'Estimasi total' : 'Total',
                value: formatRupiah(state.subtotal - promoTotal),
                bold: true,
              ),
              const SizedBox(height: AppSpacing.md),
              InfoRow(label: 'Kirim ke', value: user.address.isEmpty ? '-' : user.address),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(labelText: 'Catatan untuk penjual'),
                onChanged: vm.setNote,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
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
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Total final (termasuk harga khusus Anda, jika ada) tercantum di invoice.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );

    return PageScaffold(
      title: 'Keranjang',
      subtitle: 'Periksa jumlah barang sebelum mengirim pesanan.',
      leading: BackButton(onPressed: () => context.go('/shop')),
      child: state.lines.isEmpty
          ? const EmptyState(icon: Icons.shopping_cart_outlined, message: 'Keranjang masih kosong')
          : isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.lg,
                  children: [
                    Expanded(child: itemsCard()),
                    SizedBox(width: 340, child: summary()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    itemsCard(),
                    summary(),
                  ],
                ),
    );
  }
}

/// Kolom subtotal di tabel (dan lencana diskon baris).
class _Subtotal extends StatelessWidget {
  const _Subtotal({required this.line, required this.discount});

  final CartLine line;
  final CartLine discount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatRupiah(line.gross), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (discount.discountAmount > 0)
          Text(
            '${discount.discountLabel} −${formatRupiah(discount.discountAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(color: context.tokens.success),
          ),
      ],
    );
  }
}

/// Satu baris keranjang dalam bentuk kartu (tampilan HP).
class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.line,
    required this.discount,
    required this.product,
    required this.onSetQty,
  });

  final CartLine line;
  final CartLine discount;
  final Product? product;
  final ValueChanged<int> onSetQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          Text(line.name, style: theme.textTheme.titleSmall),
          Text(lineDetail(line), style: theme.textTheme.bodySmall),
          Row(
            children: [
              _LineControls(line: line, product: product, onSetQty: onSetQty),
              const Spacer(),
              Text(formatRupiah(line.gross), style: theme.textTheme.titleSmall),
            ],
          ),
          if (discount.discountAmount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${discount.discountLabel} −${formatRupiah(discount.discountAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.success),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kontrol jumlah: kurang, ubah langsung, tambah.
class _LineControls extends StatelessWidget {
  const _LineControls({required this.line, required this.product, required this.onSetQty});

  final CartLine line;
  final Product? product;
  final ValueChanged<int> onSetQty;

  @override
  Widget build(BuildContext context) {
    final enabled = product != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: enabled ? () => onSetQty(line.qty - 1) : null,
        ),
        TextButton(
          onPressed: enabled
              ? () async {
                  final qty = await askQuantity(context, current: line.qty, unit: line.unit);
                  if (qty != null) onSetQty(qty);
                }
              : null,
          child: Text('${line.qty}'),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: enabled ? () => onSetQty(line.qty + 1) : null,
        ),
      ],
    );
  }
}
