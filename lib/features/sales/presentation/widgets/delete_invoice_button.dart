import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/feedback.dart';
import '../../../auth/auth_providers.dart';
import '../../domain/entities/invoice.dart';
import '../../sales_providers.dart';

class DeleteInvoiceButton extends ConsumerStatefulWidget {
  const DeleteInvoiceButton({super.key, required this.invoice, this.onDeleted});

  final Invoice invoice;
  final VoidCallback? onDeleted;

  @override
  ConsumerState<DeleteInvoiceButton> createState() => _DeleteInvoiceButtonState();
}

class _DeleteInvoiceButtonState extends ConsumerState<DeleteInvoiceButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text(
          'Nota ${widget.invoice.number} dan seluruh pembayarannya akan dihapus dari riwayat dan laporan. '
          'Stok barang akan dikembalikan jika transaksi belum dibatalkan. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus transaksi')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(salesRepositoryProvider)
          .deleteInvoice(invoiceId: widget.invoice.id, by: ref.read(currentUserProvider));
      if (!mounted) return;
      showMessage(context, 'Transaksi dihapus dan stok dikembalikan');
      widget.onDeleted?.call();
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
      tooltip: 'Hapus transaksi',
      onPressed: _busy ? null : _delete,
      color: Theme.of(context).colorScheme.error,
      icon: _busy
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.delete_outline),
    );
  }
}
