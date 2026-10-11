import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../auth/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';
import '../viewmodels/stock_view_models.dart';
import 'receipt_edit_dialog.dart';
import '../../../../core/router/app_shell.dart';

class StockInView extends StatelessWidget {
  const StockInView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(leading: shellMenuButton(context), 
          title: const Text('Stok Masuk'),
          bottom: const TabBar(tabs: [Tab(text: 'Input'), Tab(text: 'Riwayat')]),
        ),
        body: const TabBarView(children: [_StockInForm(), _ReceiptHistory()]),
      ),
    );
  }
}

class _StockInForm extends ConsumerStatefulWidget {
  const _StockInForm();

  @override
  ConsumerState<_StockInForm> createState() => _StockInFormState();
}

class _StockInFormState extends ConsumerState<_StockInForm> {
  final _supplier = TextEditingController();
  final _docNo = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _price = TextEditingController();
  Product? _selected;
  int _pickerKey = 0;

  @override
  void dispose() {
    for (final c in [_supplier, _docNo, _qty, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  void _add() {
    final product = _selected;
    if (product == null) return;
    try {
      ref.read(stockInViewModelProvider.notifier).addItem(
            product,
            qty: parseRupiah(_qty.text),
            buyPrice: parseRupiah(_price.text),
          );
      setState(() {
        _selected = null;
        _pickerKey++;
        _qty.text = '1';
        _price.clear();
      });
    } on AppException catch (e) {
      showMessage(context, e.message, isError: true);
    }
  }

  Future<void> _submit() async {
    final ok = await ref.read(stockInViewModelProvider.notifier).submit();
    if (ok && mounted) {
      _supplier.clear();
      _docNo.clear();
      showMessage(context, 'Stok masuk disimpan, stok bertambah.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockInViewModelProvider);
    final vm = ref.read(stockInViewModelProvider.notifier);
    ref.listen(stockInViewModelProvider.select((s) => s.submission), (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 280,
              child: TextField(controller: _supplier, decoration: const InputDecoration(labelText: 'Supplier'), onChanged: vm.setSupplier),
            ),
            SizedBox(
              width: 220,
              child: TextField(controller: _docNo, decoration: const InputDecoration(labelText: 'No. faktur / surat jalan'), onChanged: vm.setDocNo),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(formatDate(state.date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) vm.setDate(picked);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Barang', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: ProductPicker(
                key: ValueKey(_pickerKey),
                onSelected: (p) => setState(() => _selected = p),
              ),
            ),
            SizedBox(
              width: 96,
              child: TextField(controller: _qty, keyboardType: TextInputType.number, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Qty')),
            ),
            SizedBox(
              width: 160,
              child: TextField(controller: _price, keyboardType: TextInputType.number, inputFormatters: digits, decoration: const InputDecoration(labelText: 'Harga beli (Rp)')),
            ),
            FilledButton.tonalIcon(onPressed: _selected == null ? null : _add, icon: const Icon(Icons.add), label: const Text('Tambah')),
          ],
        ),
        const SizedBox(height: 16),
        if (state.items.isEmpty)
          const EmptyState(icon: Icons.move_to_inbox_outlined, message: 'Belum ada barang')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < state.items.length; i++)
                  ListTile(
                    title: Text(state.items[i].productName),
                    subtitle: Text('${state.items[i].qty} × ${formatRupiah(state.items[i].buyPrice)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(formatRupiah(state.items[i].total)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => vm.removeItem(i)),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Text(formatRupiah(state.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: state.items.isEmpty || state.submission.isLoading ? null : _submit,
          icon: const Icon(Icons.save),
          label: const Text('Simpan stok masuk'),
        ),
      ],
    );
  }
}

class _ReceiptHistory extends ConsumerWidget {
  const _ReceiptHistory();

  Future<void> _edit(BuildContext context, WidgetRef ref, StockReceipt receipt) async {
    final isOwner = ref.read(currentUserProvider).isOwner;
    final result = await ReceiptEditDialog.show(context, receipt, requireReason: !isOwner);
    if (result == null) return;
    final ok = await ref
        .read(stockActionsViewModelProvider.notifier)
        .changeReceipt(receipt, result.items, reason: result.reason);
    if (!context.mounted) return;
    if (ok) {
      showMessage(context, isOwner ? 'Dokumen diperbarui' : 'Pengajuan dikirim ke Owner');
    } else {
      showMessage(context, '${ref.read(stockActionsViewModelProvider).error}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(currentUserProvider).isOwner;
    return AsyncValueView(
      value: ref.watch(stockReceiptsProvider),
      data: (receipts) => receipts.isEmpty
          ? const EmptyState(icon: Icons.history, message: 'Belum ada stok masuk')
          : ListView.separated(
              itemCount: receipts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = receipts[i];
                return ExpansionTile(
                  title: Text('${r.supplier}${r.docNo.isEmpty ? '' : ' · ${r.docNo}'}'),
                  subtitle: Text('${formatDate(r.date)} · ${r.items.length} barang · ${formatRupiah(r.total)}'
                      '${isOwner ? ' · ${r.createdByName}' : ''}'),
                  trailing: r.isLocked
                      ? const Chip(label: Text('Menunggu ACC'))
                      : TextButton(
                          onPressed: () => _edit(context, ref, r),
                          child: Text(isOwner ? 'Ubah' : 'Ajukan perubahan'),
                        ),
                  children: [
                    for (final item in r.items)
                      ListTile(
                        dense: true,
                        title: Text(item.productName),
                        trailing: Text('${item.qty} × ${formatRupiah(item.buyPrice)}'),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
