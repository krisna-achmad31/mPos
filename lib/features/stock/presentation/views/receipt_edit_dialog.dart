import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_layout.dart';
import '../../domain/entities/stock_receipt.dart';

class ReceiptEditResult {
  const ReceiptEditResult(this.items, this.reason);

  final List<StockReceiptItem> items;
  final String reason;
}

/// Mengubah qty per baris dokumen stok masuk. SPV wajib memberi alasan.
class ReceiptEditDialog extends StatefulWidget {
  const ReceiptEditDialog({super.key, required this.receipt, required this.requireReason});

  final StockReceipt receipt;
  final bool requireReason;

  static Future<ReceiptEditResult?> show(BuildContext context, StockReceipt receipt, {required bool requireReason}) =>
      showDialog<ReceiptEditResult>(
        context: context,
        builder: (_) => ReceiptEditDialog(receipt: receipt, requireReason: requireReason),
      );

  @override
  State<ReceiptEditDialog> createState() => _ReceiptEditDialogState();
}

class _ReceiptEditDialogState extends State<ReceiptEditDialog> {
  late final _qty = [for (final i in widget.receipt.items) TextEditingController(text: '${i.qty}')];
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in _qty) {
      c.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.requireReason && _reason.text.trim().isEmpty) {
      setState(() => _error = 'Alasan wajib diisi');
      return;
    }
    final items = <StockReceiptItem>[];
    for (var i = 0; i < widget.receipt.items.length; i++) {
      final qty = int.tryParse(_qty[i].text) ?? 0;
      if (qty > 0) items.add(widget.receipt.items[i].copyWith(qty: qty));
    }
    Navigator.pop(context, ReceiptEditResult(items, _reason.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return AlertDialog(
      title: Text(widget.requireReason ? 'Ajukan koreksi' : 'Ubah stok masuk'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              for (var i = 0; i < widget.receipt.items.length; i++)
                Row(
                  spacing: AppSpacing.md,
                  children: [
                    Expanded(
                      child: Text(
                        widget.receipt.items[i].productName,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        controller: _qty[i],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Qty', helperText: '0 = hapus'),
                      ),
                    ),
                  ],
                ),
              if (widget.requireReason)
                TextField(
                  controller: _reason,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: 'Alasan koreksi', errorText: _error),
                ),
              if (widget.requireReason)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: tokens.warningTint,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Text(
                    'Stok tidak berubah sampai Owner menyetujui pengajuan ini.',
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.warning),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: Text(widget.requireReason ? 'Ajukan' : 'Simpan')),
      ],
    );
  }
}
