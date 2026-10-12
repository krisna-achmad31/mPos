import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/services/sale_calculator.dart';
import '../../sales_providers.dart';
import '../viewmodels/report_view_model.dart';
import '../widgets/month_switcher.dart';
import '../../../../core/router/app_shell.dart';

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

    return Scaffold(
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: const Text('Riwayat Nota'),
        actions: [if (user.isOwner) const MonthSwitcher(), const SizedBox(width: 12)],
      ),
      body: AsyncValueView(
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              spacing: 8,
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
          if (list.isEmpty) {
            return Column(
              children: [
                chips,
                const Expanded(
                  child: EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada nota'),
                ),
              ],
            );
          }
          return Column(
            children: [
              chips,
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final inv = list[i];
                    return ListTile(
                      title: Text('${inv.number} · ${inv.customerName}'),
                      subtitle: Text(
                        '${formatDateTime(inv.createdAt)} · ${inv.source == InvoiceSource.pos ? 'Kasir' : 'Online'}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatRupiah(inv.totals.total)),
                          Text(
                            _statusLabel(inv, now),
                            style: TextStyle(
                              color: inv.voided || inv.paymentStatus != PaymentStatus.paid
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => context.go('$base/invoices/${inv.id}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _statusLabel(Invoice inv, DateTime now) {
    if (inv.voided) return 'Batal';
    if (inv.isOpenCredit) {
      final due = inv.dueDate;
      if (due == null) return 'Tempo';
      return '${inv.isOverdue(now) ? 'Lewat tempo' : 'Tempo'} · ${formatDate(due)}';
    }
    final method = inv.paymentStatus == PaymentStatus.paid ? inv.paymentMethod?.label : null;
    return method == null ? inv.paymentStatus.label : '${inv.paymentStatus.label} · $method';
  }
}
