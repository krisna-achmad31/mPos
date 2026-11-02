import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';

/// Tombol hapus dokumen stok masuk; hanya tampil untuk Owner.
class DeleteReceiptButton extends ConsumerStatefulWidget {
  const DeleteReceiptButton({super.key, required this.receipt});

  final StockReceipt receipt;

  @override
  ConsumerState<DeleteReceiptButton> createState() => _DeleteReceiptButtonState();
}

class _DeleteReceiptButtonState extends ConsumerState<DeleteReceiptButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final r = widget.receipt;
    final label = r.docNo.isEmpty ? r.supplier : '${r.supplier} · ${r.docNo}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus stok masuk?'),
        content: Text(
          'Dokumen $label akan dihapus dari riwayat. Stok barangnya akan dikurangi kembali '
          'dan HPP rata-rata dihitung ulang. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus stok masuk')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(stockRepositoryProvider).deleteReceipt(receipt: r, by: ref.read(currentUserProvider));
      if (mounted) showMessage(context, 'Stok masuk dihapus dan stok dikurangi kembali');
    } catch (error) {
      if (mounted) showMessage(context, '$error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(currentUserProvider).isOwner) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Hapus stok masuk',
      onPressed: _busy ? null : _delete,
      color: Theme.of(context).colorScheme.error,
      icon: _busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.delete_outline),
    );
  }
}
