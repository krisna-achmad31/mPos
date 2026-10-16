import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../products/domain/entities/product.dart';
import '../viewmodels/stock_view_models.dart';

class StockOpnameDialog extends ConsumerStatefulWidget {
  const StockOpnameDialog({super.key, required this.product});

  final Product product;

  static Future<void> show(BuildContext context, Product product) =>
      showDialog(context: context, builder: (_) => StockOpnameDialog(product: product));

  @override
  ConsumerState<StockOpnameDialog> createState() => _StockOpnameDialogState();
}

class _StockOpnameDialogState extends ConsumerState<StockOpnameDialog> {
  final _physical = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _physical.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _diff => parseRupiah(_physical.text) - widget.product.stock;

  Future<void> _save() async {
    if (_physical.text.isEmpty) return;
    final ok = await ref
        .read(stockActionsViewModelProvider.notifier)
        .opname(widget.product, parseRupiah(_physical.text), _note.text.trim());
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showMessage(context, 'Stok ${widget.product.name} disesuaikan');
    } else {
      showMessage(context, '${ref.read(stockActionsViewModelProvider).error}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(stockActionsViewModelProvider).isLoading;
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final filled = _physical.text.isNotEmpty;
    final diff = _diff;

    return AlertDialog(
      title: Text('Stok opname · ${widget.product.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.md,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.xs,
                  children: [
                    InfoRow(label: 'Stok sistem', value: '${widget.product.stock} ${widget.product.unit}'),
                    if (filled)
                      InfoRow(
                        label: 'Selisih',
                        value: '${diff > 0 ? '+' : ''}$diff ${widget.product.unit}',
                        valueColor: diff == 0 ? tokens.success : tokens.warning,
                        bold: true,
                      ),
                  ],
                ),
                TextField(
                  controller: _physical,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Hasil hitung fisik'),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Alasan penyesuaian'),
                ),
                if (filled && diff != 0)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: tokens.warningTint,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: tokens.warning),
                        Expanded(
                          child: Text(
                            'Stok akan berubah dari ${widget.product.stock} menjadi ${parseRupiah(_physical.text)} '
                            '${widget.product.unit}. Penyesuaian dicatat pada riwayat stok.',
                            style: theme.textTheme.bodySmall?.copyWith(color: tokens.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
