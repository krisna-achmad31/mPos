import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/change_request.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';
import '../viewmodels/stock_view_models.dart';

/// Owner: ACC / tolak pengajuan. SPV: memantau status pengajuannya.
class ChangeRequestsView extends ConsumerWidget {
  const ChangeRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(currentUserProvider).isOwner;
    return PageScaffold(
      title: isOwner ? 'Persetujuan' : 'Pengajuan saya',
      subtitle: isOwner
          ? 'Tinjau perubahan stok sebelum diterapkan.'
          : 'Pantau status pengajuan koreksi stok yang Anda kirim.',
      child: AsyncValueView(
        value: ref.watch(changeRequestsProvider),
        data: (requests) => requests.isEmpty
            ? const EmptyState(icon: Icons.fact_check_outlined, message: 'Tidak ada pengajuan')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final r in requests) _RequestCard(request: r, canDecide: isOwner)],
              ),
      ),
    );
  }
}

BadgeTone _toneFor(ChangeRequestStatus status) => switch (status) {
  ChangeRequestStatus.pending => BadgeTone.warning,
  ChangeRequestStatus.approved => BadgeTone.success,
  ChangeRequestStatus.rejected => BadgeTone.danger,
};

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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final names = <String, String>{
      for (final i in [...request.oldItems, ...request.newItems]) i.productId: i.productName,
    };
    int qtyOf(List<StockReceiptItem> items, String id) =>
        items.where((i) => i.productId == id).fold(0, (sum, i) => sum + i.qty);
    final pending = request.status == ChangeRequestStatus.pending;

    return SectionCard(
      title: canDecide
          ? 'Review koreksi · ${request.receiptDocNo.isEmpty ? '-' : request.receiptDocNo}'
          : 'Pengajuan · ${request.receiptDocNo.isEmpty ? '-' : request.receiptDocNo}',
      trailing: StatusBadge(request.status.label, tone: _toneFor(request.status)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.xs,
            children: [
              InfoRow(label: 'Diajukan oleh', value: request.requestedByName),
              InfoRow(label: 'Tanggal', value: formatDateTime(request.createdAt)),
              InfoRow(label: 'Alasan', value: request.reason),
            ],
          ),
          AppDataTable(
            columns: const ['Barang', 'Sebelum', 'Sesudah'],
            flex: const [3, 1, 1],
            emptyLabel: 'Tidak ada perubahan barang.',
            rows: [
              for (final entry in names.entries)
                [
                  Text(entry.value),
                  Text('${qtyOf(request.oldItems, entry.key)}'),
                  Text(
                    '${qtyOf(request.newItems, entry.key)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
            ],
          ),
          if (request.decisionNote.isNotEmpty)
            Text(
              'Catatan Owner: ${request.decisionNote}',
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          if (canDecide && pending)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(onPressed: () => _decide(context, ref, false), child: const Text('Tolak pengajuan')),
                FilledButton.icon(
                  onPressed: () => _decide(context, ref, true),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Setujui koreksi'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
