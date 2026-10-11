import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money.dart';
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
    return AlertDialog(
      title: Text('Stock opname · ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Text('Stok sistem: ${widget.product.stock} ${widget.product.unit}'),
          TextField(
            controller: _physical,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Stok fisik'),
            onChanged: (_) => setState(() {}),
          ),
          if (_physical.text.isNotEmpty) Text('Selisih: ${_diff > 0 ? '+' : ''}$_diff'),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Keterangan')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
