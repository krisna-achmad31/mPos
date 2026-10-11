import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/change_request.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';
import '../viewmodels/stock_view_models.dart';
import '../../../../core/router/app_shell.dart';

/// Owner: ACC / tolak pengajuan. SPV: memantau status pengajuannya.
class ChangeRequestsView extends ConsumerWidget {
  const ChangeRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(currentUserProvider).isOwner;
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: Text(isOwner ? 'Approval Perubahan' : 'Pengajuan Saya')),
      body: AsyncValueView(
        value: ref.watch(changeRequestsProvider),
        data: (requests) => requests.isEmpty
            ? const EmptyState(icon: Icons.fact_check_outlined, message: 'Tidak ada pengajuan')
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [for (final r in requests) _RequestCard(request: r, canDecide: isOwner)],
              ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.canDecide});

  final ChangeRequest request;
  final bool canDecide;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    var note = '';
    if (!approve) {
      final reason = await askReason(context, title: 'Tolak pengajuan', label: 'Catatan untuk SPV');
      if (reason == null) return;
      note = reason;
    }
    final ok = await ref.read(stockActionsViewModelProvider.notifier).decide(request, approve: approve, note: note);
    if (!context.mounted) return;
    if (ok) {
      showMessage(context, approve ? 'Disetujui, stok diperbarui' : 'Pengajuan ditolak');
    } else {
      showMessage(context, '${ref.read(stockActionsViewModelProvider).error}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = <String, String>{
      for (final i in [...request.oldItems, ...request.newItems]) i.productId: i.productName,
    };
    int qtyOf(List<StockReceiptItem> items, String id) =>
        items.where((i) => i.productId == id).fold(0, (sum, i) => sum + i.qty);
    final pending = request.status == ChangeRequestStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Dokumen ${request.receiptDocNo.isEmpty ? '-' : request.receiptDocNo}',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                Chip(label: Text(request.status.label)),
              ],
            ),
            Text('${request.requestedByName} · ${formatDateTime(request.createdAt)}'),
            Text('Alasan: ${request.reason}'),
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(), 2: FlexColumnWidth()},
              children: [
                const TableRow(children: [Text('Barang'), Text('Sebelum'), Text('Sesudah')]),
                for (final entry in names.entries)
                  TableRow(children: [
                    Text(entry.value),
                    Text('${qtyOf(request.oldItems, entry.key)}'),
                    Text('${qtyOf(request.newItems, entry.key)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
              ],
            ),
            if (request.decisionNote.isNotEmpty) Text('Catatan Owner: ${request.decisionNote}'),
            if (canDecide && pending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: 8,
                children: [
                  OutlinedButton(onPressed: () => _decide(context, ref, false), child: const Text('Tolak')),
                  FilledButton(onPressed: () => _decide(context, ref, true), child: const Text('Setujui')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
