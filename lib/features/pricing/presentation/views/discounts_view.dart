import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/discount.dart';
import '../../pricing_providers.dart';
import '../viewmodels/discount_view_model.dart';
import 'discount_form_dialog.dart';

/// Harga khusus & promo (padanan frame `08 · Owner / Harga khusus & promo`).
class DiscountsView extends ConsumerWidget {
  const DiscountsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(discountViewModelProvider, (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    return PageScaffold(
      title: 'Harga khusus & promo',
      subtitle: 'Atur potongan harga untuk pelanggan, produk, atau periode tertentu.',
      actions: [
        FilledButton.icon(
          onPressed: () => DiscountFormDialog.show(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat promo'),
        ),
      ],
      scrollable: false,
      child: AsyncValueView(
        value: ref.watch(discountsProvider),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.local_offer_outlined,
                message: 'Belum ada harga khusus atau promo',
                title: 'Belum ada promo',
              )
            : ListView(
                padding: EdgeInsets.zero,
                children: [for (final d in list) _DiscountCard(discount: d)],
              ),
      ),
    );
  }
}

/// Status promo menurut tanggal berlaku dan tombol aktif/nonaktif.
(String, BadgeTone) _statusOf(Discount d, DateTime now) {
  if (d.start != null && d.start!.isAfter(now)) return ('Akan datang', BadgeTone.warning);
  if (d.end != null && d.end!.isBefore(now)) return ('Berakhir', BadgeTone.danger);
  if (d.active) return ('Aktif', BadgeTone.success);
  return ('Nonaktif', BadgeTone.neutral);
}

class _DiscountCard extends ConsumerWidget {
  const _DiscountCard({required this.discount});

  final Discount discount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final d = discount;
    final now = DateTime.now();
    final target = [
      d.productId == null ? 'Semua produk' : d.productName,
      d.customerId == null ? 'semua customer' : d.customerName,
    ].join(' · ');
    final period = d.start == null && d.end == null
        ? 'Tanpa batas waktu'
        : '${d.start == null ? '…' : formatDate(d.start!)} – ${d.end == null ? '…' : formatDate(d.end!)}';
    final visibility = d.visibleInCatalog
        ? (d.customerId == null ? 'Tampil di katalog semua pelanggan' : 'Tampil di katalog ${d.customerName}')
        : 'Tersembunyi, muncul di invoice';

    final (statusLabel, statusTone) = _statusOf(d, now);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.md,
            children: [
              Expanded(
                child: Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      d.kind == DiscountKind.special ? Icons.person_pin_outlined : Icons.campaign_outlined,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    Flexible(
                      child: Text(
                        d.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: d.active,
                onChanged: (v) => ref.read(discountViewModelProvider.notifier).setActive(d, v),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              StatusBadge(d.valueLabel, tone: BadgeTone.info),
              StatusBadge(statusLabel, tone: statusTone),
            ],
          ),
          Text('${d.kind.label} · $target', style: theme.textTheme.bodyMedium),
          Text(period, style: theme.textTheme.bodySmall),
          Text(visibility, style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => DiscountFormDialog.show(context, initial: d),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Ubah'),
            ),
          ),
        ],
      ),
    );
  }
}
