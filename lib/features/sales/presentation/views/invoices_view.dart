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

/// Riwayat nota. Owner: per bulan + filter belum lunas. Customer: semua notanya.
class InvoicesView extends ConsumerStatefulWidget {
  const InvoicesView({super.key});

  @override
  ConsumerState<InvoicesView> createState() => _InvoicesViewState();
}

class _InvoicesViewState extends ConsumerState<InvoicesView> {
  bool _unpaidOnly = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final month = ref.watch(reportMonthProvider);
    final invoices = user.isOwner ? ref.watch(invoicesInMonthProvider(month)) : ref.watch(myInvoicesProvider);
    final base = user.isOwner ? '/owner' : '/shop';

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), 
        title: const Text('Riwayat Nota'),
        actions: [
          if (user.isOwner) const MonthSwitcher(),
          FilterChip(
            label: const Text('Belum lunas'),
            selected: _unpaidOnly,
            onSelected: (v) => setState(() => _unpaidOnly = v),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView(
        value: invoices,
        data: (all) {
          final list = _unpaidOnly ? all.where((i) => !i.voided && i.remaining > 0).toList() : all;
          if (list.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, message: 'Belum ada nota');
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final inv = list[i];
              return ListTile(
                title: Text('${inv.number} · ${inv.customerName}'),
                subtitle: Text('${formatDateTime(inv.createdAt)} · ${inv.source == InvoiceSource.pos ? 'Kasir' : 'Online'}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatRupiah(inv.totals.total)),
                    Text(
                      inv.voided ? 'Batal' : inv.paymentStatus.label,
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
          );
        },
      ),
    );
  }
}
