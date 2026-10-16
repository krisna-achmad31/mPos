import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../products/domain/entities/product.dart';
import '../../domain/entities/stock_receipt.dart';
import '../../stock_providers.dart';
import '../viewmodels/stock_view_models.dart';
import 'receipt_edit_dialog.dart';

class StockInView extends StatelessWidget {
  const StockInView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: PageScaffold(
        title: 'Stok masuk',
        subtitle: 'Catat penerimaan barang dan biaya pembelian.',
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TabBar(
              tabs: [Tab(text: 'Input'), Tab(text: 'Riwayat')],
              dividerColor: Colors.transparent,
            ),
            const Expanded(child: TabBarView(children: [_StockInForm(), _ReceiptHistory()])),
          ],
        ),
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

  /// Isi kemasan yang dipilih (1 = satuan dasar).
  int _contents = 1;

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
      // Qty & harga beli per kemasan dikonversi ke satuan dasar (stok selalu dalam satuan dasar).
      ref.read(stockInViewModelProvider.notifier).addItem(
            product,
            qty: parseRupiah(_qty.text) * _contents,
            buyPrice: (parseRupiah(_price.text) / _contents).round(),
          );
      setState(() {
        _selected = null;
        _contents = 1;
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
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        SectionCard(
          title: 'Penerimaan barang',
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _supplier,
                  decoration: const InputDecoration(labelText: 'Pemasok'),
                  onChanged: vm.setSupplier,
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _docNo,
                  decoration: const InputDecoration(labelText: 'Nomor referensi'),
                  onChanged: vm.setDocNo,
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.event, size: 18),
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
        ),
        SectionCard(
          title: 'Barang diterima',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 320,
                    child: ProductPicker(
                      key: ValueKey(_pickerKey),
                      includeBundles: false,
                      label: 'Tambah produk',
                      onSelected: (p) => setState(() {
                        _selected = p;
                        _contents = 1;
                      }),
                    ),
                  ),
                  if (_selected != null && _selected!.packsBySize.isNotEmpty)
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(_selected!.id),
                        initialValue: _contents,
                        decoration: const InputDecoration(labelText: 'Satuan'),
                        items: [
                          DropdownMenuItem(value: 1, child: Text(_selected!.unit)),
                          for (final pack in _selected!.packsBySize)
                            DropdownMenuItem(value: pack.contents, child: Text('${pack.name} (isi ${pack.contents})')),
                        ],
                        onChanged: (v) => setState(() => _contents = v ?? 1),
                      ),
                    ),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(labelText: 'Qty'),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: InputDecoration(
                        labelText: _contents > 1 ? 'Harga beli per kemasan' : 'Harga beli (Rp)',
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _selected == null ? null : _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              if (state.items.isEmpty)
                const EmptyState(icon: Icons.move_to_inbox_outlined, message: 'Belum ada barang')
              else
                _ItemsList(
                  items: state.items,
                  onRemove: vm.removeItem,
                ),
              if (state.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total penerimaan',
                          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.muted),
                        ),
                      ),
                      Text(
                        formatRupiah(state.total),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.items.isEmpty || state.submission.isLoading ? null : _submit,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Simpan penerimaan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Daftar barang diterima: tabel di layar lebar, baris kartu di HP.
class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.items, required this.onRemove});

  final List<StockReceiptItem> items;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    if (context.deviceClass == DeviceClass.phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                spacing: AppSpacing.md,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(items[i].productName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          '${items[i].qty} × ${formatRupiah(items[i].buyPrice)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(formatRupiah(items[i].total), style: theme.textTheme.bodyMedium),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Hapus',
                    onPressed: () => onRemove(i),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return AppDataTable(
      columns: const ['Produk', 'Jumlah diterima', 'Harga beli / unit', 'Subtotal'],
      flex: const [3, 2, 2, 2],
      rows: [
        for (var i = 0; i < items.length; i++)
          [
            Text(items[i].productName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${items[i].qty}'),
            Text(formatRupiah(items[i].buyPrice)),
            Row(
              spacing: AppSpacing.xs,
              children: [
                Text(formatRupiah(items[i].total), style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onRemove(i),
                ),
              ],
            ),
          ],
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              children: [for (final r in receipts) _receiptCard(context, ref, r, isOwner)],
            ),
    );
  }

  Widget _receiptCard(BuildContext context, WidgetRef ref, StockReceipt r, bool isOwner) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final status = r.isLocked
        ? const StatusBadge('Koreksi diajukan', tone: BadgeTone.warning)
        : const StatusBadge('Diterima', tone: BadgeTone.success);

    return SectionCard(
      title: '${r.supplier}${r.docNo.isEmpty ? '' : ' · ${r.docNo}'}',
      subtitle: '${formatDate(r.date)} · ${r.items.length} barang · ${formatRupiah(r.total)}'
          '${isOwner ? ' · ${r.createdByName}' : ''}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.sm,
        children: [
          status,
          if (!r.isLocked)
            TextButton(
              onPressed: () => _edit(context, ref, r),
              child: Text(isOwner ? 'Ubah' : 'Ajukan koreksi'),
            ),
        ],
      ),
      child: AppDataTable(
        columns: const ['Produk', 'Jumlah diterima', 'Harga beli / unit', 'Subtotal'],
        flex: const [3, 2, 2, 2],
        emptyLabel: 'Belum ada barang.',
        rows: [
          for (final item in r.items)
            [
              Text(item.productName, style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink)),
              Text('${item.qty}'),
              Text(formatRupiah(item.buyPrice)),
              Text(formatRupiah(item.total), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
        ],
      ),
    );
  }
}
