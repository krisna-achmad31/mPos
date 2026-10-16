import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/report_view_model.dart';
import '../widgets/month_switcher.dart';

/// Filter riwayat nota.
enum InvoiceFilter {
  all('Semua'),
  unpaid('Belum lunas'),
  cash('Tunai'),
  transfer('Transfer'),
  qris('QRIS'),
  credit('Tempo');

  const InvoiceFilter(this.label);

  final String label;

  bool matches(Invoice inv) => switch (this) {
    all => true,
    unpaid => !inv.voided && inv.remaining > 0,
    cash => _paidWith(inv, PaymentMethod.cash),
    transfer => _paidWith(inv, PaymentMethod.transfer),
    qris => _paidWith(inv, PaymentMethod.qris),
    // Hanya tempo yang belum dibayar; setelah ditandai lunas pindah ke metode pelunasannya.
    credit => inv.isOpenCredit,
  };

  static bool _paidWith(Invoice inv, PaymentMethod m) => !inv.voided && !inv.isOpenCredit && inv.paymentMethod == m;
}

/// Riwayat nota. Owner: per bulan. Customer: semua notanya. Bisa difilter per metode bayar / tempo.
class InvoicesView extends ConsumerStatefulWidget {
  const InvoicesView({super.key});

  @override
  ConsumerState<InvoicesView> createState() => _InvoicesViewState();
}

class _InvoicesViewState extends ConsumerState<InvoicesView> {
  var _filter = InvoiceFilter.all;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final month = ref.watch(reportMonthProvider);
    final invoices = user.isOwner ? ref.watch(invoicesInMonthProvider(month)) : ref.watch(myInvoicesProvider);
    final base = user.isOwner ? '/owner' : '/shop';

    return PageScaffold(
      title: 'Riwayat nota',
      subtitle: user.isOwner
          ? 'Pantau transaksi, pembayaran, dan jatuh tempo.'
          : 'Semua nota belanjamu tersimpan di sini.',
      appBarActions: user.isOwner ? const [MonthSwitcher()] : const [],
      scrollable: false,
      child: AsyncValueView(
        value: invoices,
        data: (all) {
          final list = all.where(_filter.matches).toList();
          // Tempo: yang paling dekat jatuh tempo di atas.
          if (_filter == InvoiceFilter.credit) {
            list.sort((a, b) => (a.dueDate ?? DateTime(9999)).compareTo(b.dueDate ?? DateTime(9999)));
          }
          final now = DateTime.now();
          final chips = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                for (final f in InvoiceFilter.values)
                  ChoiceChip(
                    label: Text(f == InvoiceFilter.all ? f.label : '${f.label} (${all.where(f.matches).length})'),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              chips,
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Belum ada nota',
                        message: 'Tidak ada nota yang cocok dengan filter ini.',
                      )
                    : _InvoiceList(list: list, base: base, now: now),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _statusLabel(Invoice inv, DateTime now) {
  if (inv.voided) return 'Batal';
  if (inv.isOpenCredit) {
    final due = inv.dueDate;
    if (due == null) return 'Tempo';
    return '${inv.isOverdue(now) ? 'Lewat tempo' : 'Tempo'} · ${formatDate(due)}';
  }
  final method = inv.paymentStatus == PaymentStatus.paid ? inv.paymentMethod?.label : null;
  return method == null ? inv.paymentStatus.label : '${inv.paymentStatus.label} · $method';
}

BadgeTone _statusTone(Invoice inv, DateTime now) {
  if (inv.voided) return BadgeTone.danger;
  if (inv.isOpenCredit) return inv.isOverdue(now) ? BadgeTone.danger : BadgeTone.warning;
  return switch (inv.paymentStatus) {
    PaymentStatus.paid => BadgeTone.success,
    PaymentStatus.partial => BadgeTone.warning,
    PaymentStatus.unpaid => BadgeTone.danger,
  };
}

StatusBadge _statusBadge(Invoice inv, DateTime now) => StatusBadge(_statusLabel(inv, now), tone: _statusTone(inv, now));

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.list, required this.base, required this.now});

  final List<Invoice> list;
  final String base;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    if (context.deviceClass == DeviceClass.phone) {
      return ListView.separated(
        itemCount: list.length,
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, i) => _InvoiceCard(
          invoice: list[i],
          now: now,
          onTap: () => context.go('$base/invoices/${list[i].id}'),
        ),
      );
    }

    return SingleChildScrollView(
      child: AppDataTable(
        columns: const ['Nomor nota', 'Pelanggan', 'Tanggal', 'Total', 'Status'],
        flex: const [3, 3, 2, 2, 2],
        onTap: (i) => context.go('$base/invoices/${list[i].id}'),
        emptyLabel: 'Belum ada nota',
        rows: [
          for (final inv in list)
            [
              Text(inv.number, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                inv.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(formatDate(inv.createdAt), style: Theme.of(context).textTheme.bodySmall),
              Text(formatRupiah(inv.totals.total), style: const TextStyle(fontWeight: FontWeight.w600)),
              Align(alignment: Alignment.centerLeft, child: _statusBadge(inv, now)),
            ],
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.now, required this.onTap});

  final Invoice invoice;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: tokens.line),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Row(
                spacing: AppSpacing.sm,
                children: [
                  Expanded(
                    child: Text(
                      invoice.number,
                      style: theme.textTheme.titleSmall?.copyWith(color: tokens.ink),
                    ),
                  ),
                  _statusBadge(invoice, now),
                ],
              ),
              Text(
                '${invoice.customerName} · ${formatDateTime(invoice.createdAt)} · '
                '${invoice.source == InvoiceSource.pos ? 'Kasir' : 'Pesanan online'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    formatRupiah(invoice.totals.total),
                    style: theme.textTheme.titleMedium?.copyWith(color: tokens.ink),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 20, color: tokens.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
