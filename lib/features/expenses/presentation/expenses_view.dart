import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_layout.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/presentation/viewmodels/report_view_model.dart';
import '../../sales/presentation/widgets/month_switcher.dart';
import '../domain/expense.dart';
import '../expense_providers.dart';

/// Pengeluaran operasional (padanan frame `09 · Owner / Pengeluaran`, juga
/// dipakai workspace Kopi di frame `37`).
class ExpensesView extends ConsumerWidget {
  const ExpensesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(reportMonthProvider);
    return PageScaffold(
      title: 'Pengeluaran',
      subtitle: 'Catat biaya operasional dan pantau total per bulan.',
      actions: [
        const MonthSwitcher(),
        FilledButton.icon(
          onPressed: () => _ExpenseDialog.show(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Catat pengeluaran'),
        ),
      ],
      scrollable: false,
      child: AsyncValueView(
        value: ref.watch(expensesInMonthProvider(month)),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_outlined,
              message: 'Belum ada pengeluaran bulan ini',
              title: 'Tidak ada pengeluaran',
            );
          }
          final total = list.fold(0, (s, e) => s + e.amount);
          final average = total ~/ list.length;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              KpiRow(
                children: [
                  KpiTile(
                    label: 'Total pengeluaran',
                    value: formatRupiah(total),
                    hint: 'Bulan berjalan',
                    icon: Icons.payments_outlined,
                    highlight: true,
                    width: null,
                  ),
                  KpiTile(
                    label: 'Jumlah catatan',
                    value: '${list.length}',
                    hint: 'Catatan tercatat',
                    icon: Icons.receipt_long_outlined,
                    width: null,
                  ),
                  KpiTile(
                    label: 'Rata-rata',
                    value: formatRupiah(average),
                    hint: 'Per catatan',
                    icon: Icons.analytics_outlined,
                    width: null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionCard(
                title: 'Daftar pengeluaran',
                subtitle: 'Ketuk baris untuk mengubah catatan.',
                child: AppDataTable(
                  columns: const ['Tanggal', 'Keterangan', 'Kategori', 'Nominal'],
                  flex: const [3, 4, 3, 3],
                  onTap: (i) => _ExpenseDialog.show(context, initial: list[i]),
                  emptyLabel: 'Belum ada pengeluaran bulan ini.',
                  rows: [
                    for (final e in list)
                      [
                        Text(formatDate(e.date), style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          e.note.isEmpty ? '—' : e.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(e.category),
                        Text(formatRupiah(e.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog({this.initial});

  final Expense? initial;

  static Future<void> show(BuildContext context, {Expense? initial}) =>
      showDialog(context: context, builder: (_) => _ExpenseDialog(initial: initial));

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  late final _amount = TextEditingController(text: widget.initial == null ? '' : '${widget.initial!.amount}');
  late final _note = TextEditingController(text: widget.initial?.note);
  late String _category = widget.initial?.category ?? Expense.defaultCategories.first;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref.read(expenseViewModelProvider.notifier).save(Expense(
          id: widget.initial?.id ?? '',
          date: _date,
          category: _category,
          amount: parseRupiah(_amount.text),
          note: _note.text.trim(),
        ));
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _error = '${ref.read(expenseViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = {...Expense.defaultCategories, _category}.toList();
    return AlertDialog(
      title: Text(widget.initial == null ? 'Pengeluaran baru' : 'Ubah pengeluaran'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Nominal (Rp)'),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(formatDate(_date)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan')),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: ref.watch(expenseViewModelProvider).isLoading ? null : _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
