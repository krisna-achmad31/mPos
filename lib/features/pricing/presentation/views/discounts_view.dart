import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../domain/entities/discount.dart';
import '../../pricing_providers.dart';
import '../viewmodels/discount_view_model.dart';
import 'discount_form_dialog.dart';
import '../../../../core/router/app_shell.dart';

class DiscountsView extends ConsumerWidget {
  const DiscountsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(discountViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Harga Khusus & Promo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => DiscountFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Diskon'),
      ),
      body: AsyncValueView(
        value: ref.watch(discountsProvider),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.local_offer_outlined, message: 'Belum ada harga khusus atau promo')
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _DiscountTile(discount: list[i]),
              ),
      ),
    );
  }
}

class _DiscountTile extends ConsumerWidget {
  const _DiscountTile({required this.discount});

  final Discount discount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = discount;
    final target = [
      d.productId == null ? 'Semua produk' : d.productName,
      d.customerId == null ? 'semua customer' : d.customerName,
    ].join(' · ');
    final period = d.start == null && d.end == null
        ? 'tanpa batas waktu'
        : '${d.start == null ? '…' : formatDate(d.start!)} – ${d.end == null ? '…' : formatDate(d.end!)}';
    final visibility = d.visibleInCatalog ? 'tampil di katalog' : 'tersembunyi, muncul di invoice';
    return ListTile(
      leading: Icon(d.kind == DiscountKind.special ? Icons.person_pin_outlined : Icons.campaign_outlined),
      title: Text('${d.name} · ${d.valueLabel}'),
      subtitle: Text('${d.kind.label} · $target\n$period · $visibility'),
      isThreeLine: true,
      trailing: Switch(
        value: d.active,
        onChanged: (v) => ref.read(discountViewModelProvider.notifier).setActive(d, v),
      ),
      onTap: () => DiscountFormDialog.show(context, initial: d),
    );
  }
}
