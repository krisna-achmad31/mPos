import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/services/sale_calculator.dart';
import '../viewmodels/pos_view_model.dart';
import '../widgets/totals_table.dart';
import '../../../../core/router/app_shell.dart';
import '../widgets/line_text.dart';

/// Kasir langsung untuk pembeli yang datang ke toko.
class PosView extends ConsumerWidget {
  const PosView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(posViewModelProvider.select((s) => s.message), (_, message) {
      if (message != null) {
        showMessage(context, message, isError: true);
        ref.read(posViewModelProvider.notifier).clearMessage();
      }
    });
    ref.listen(posViewModelProvider.select((s) => s.submission), (_, next) {
      if (next.hasError) showMessage(context, '${next.error}', isError: true);
    });

    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Kasir')),
      body: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _CartPanel()),
              VerticalDivider(width: 1),
              SizedBox(width: 380, child: SingleChildScrollView(child: _PaymentPanel())),
            ],
          );
        }
        return const SingleChildScrollView(
          child: Column(children: [_CartPanel(shrinkWrap: true), Divider(), _PaymentPanel()]),
        );
      }),
    );
  }
}

class _CartPanel extends ConsumerStatefulWidget {
  const _CartPanel({this.shrinkWrap = false});

  final bool shrinkWrap;

  @override
  ConsumerState<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends ConsumerState<_CartPanel> {
  int _pickerKey = 0;

  Product? _productOf(String id) => ref.read(productsProvider).value?.where((p) => p.id == id).firstOrNull;

  Future<void> _manualPrice(int index, CartLine line) async {
    final product = _productOf(line.productId);
    if (product == null) return;
    final controller = TextEditingController(text: '${line.unitPrice}');
    final price = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Harga manual · ${line.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Harga per unit (Rp)', helperText: 'Tercatat di log audit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, parseRupiah(controller.text)), child: const Text('Pakai')),
        ],
      ),
    );
    if (price == null || price <= 0) return;
    final vm = ref.read(posViewModelProvider.notifier);
    vm.removeLine(index);
    vm.addProduct(product, qty: line.qty, manualPrice: price);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posViewModelProvider);
    final vm = ref.read(posViewModelProvider.notifier);
    final priced = vm.pricedLines();

    final list = state.lines.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(32),
            child: EmptyState(icon: Icons.shopping_cart_outlined, message: 'Scan barcode atau cari produk'),
          )
        : ListView.separated(
            shrinkWrap: widget.shrinkWrap,
            physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            itemCount: state.lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final line = state.lines[i];
              final discount = priced[i].discountAmount;
              final product = _productOf(line.productId);
              return ListTile(
                title: Text(line.name),
                subtitle: Text([
                  '${lineDetail(line)} (${line.priceType.label})',
                  if (discount > 0) '${priced[i].discountLabel} −${formatRupiah(discount)}',
                ].join(' · ')),
                onLongPress: () => _manualPrice(i, line),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: product == null ? null : () => vm.setQty(i, line.qty - 1, product),
                    ),
                    TextButton(
                      onPressed: product == null
                          ? null
                          : () async {
                              final qty = await askQuantity(context, current: line.qty, unit: line.unit);
                              if (qty != null) vm.setQty(i, qty, product);
                            },
                      child: Text('${line.qty}', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: product == null ? null : () => vm.setQty(i, line.qty + 1, product),
                    ),
                    SizedBox(width: 110, child: Text(formatRupiah(line.gross - discount), textAlign: TextAlign.end)),
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'manual' ? _manualPrice(i, line) : vm.removeLine(i),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'manual', child: Text('Harga manual')),
                        PopupMenuItem(value: 'remove', child: Text('Hapus')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );

    return Column(
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ProductPicker(
            key: ValueKey(_pickerKey),
            label: 'Scan barcode / cari produk',
            onSelected: (p) {
              vm.addProduct(p);
              setState(() => _pickerKey++);
            },
          ),
        ),
        if (widget.shrinkWrap) list else Expanded(child: list),
      ],
    );
  }
}

class _PaymentPanel extends ConsumerStatefulWidget {
  const _PaymentPanel();

  @override
  ConsumerState<_PaymentPanel> createState() => _PaymentPanelState();
}

class _PaymentPanelState extends ConsumerState<_PaymentPanel> {
  final _discount = TextEditingController();
  final _amount = TextEditingController();
  final _sales = TextEditingController();
  bool _discountPercent = false;

  @override
  void dispose() {
    _discount.dispose();
    _amount.dispose();
    _sales.dispose();
    super.dispose();
  }

  void _applyDiscount() {
    final value = double.tryParse(_discount.text.replaceAll(',', '.')) ?? 0;
    ref.read(posViewModelProvider.notifier).setOrderDiscount(value <= 0
        ? const OrderDiscount.none()
        : _discountPercent
            ? OrderDiscount.percent(value)
            : OrderDiscount.amount(value));
  }

  Future<void> _checkout() async {
    final invoiceId = await ref.read(posViewModelProvider.notifier).checkout();
    if (invoiceId == null || !mounted) return;
    _discount.clear();
    _amount.clear();
    _sales.clear();
    showMessage(context, 'Transaksi tersimpan');
    context.go('/owner/invoices/$invoiceId');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(posViewModelProvider);
    final vm = ref.read(posViewModelProvider.notifier);
    final totals = ref.watch(posTotalsProvider);
    final customers = ref.watch(customersProvider).value ?? [];
    final total = totals.total;
    final given = state.amountGiven;

    String? paymentInfo;
    if (total > 0) {
      paymentInfo = switch (state.method) {
        PaymentMethod.cash => given >= total ? 'Kembalian ${formatRupiah(given - total)}' : 'Uang kurang ${formatRupiah(total - given)}',
        PaymentMethod.transfer || PaymentMethod.qris => 'Dianggap lunas',
        PaymentMethod.downPayment || PaymentMethod.credit => 'Sisa tagihan ${formatRupiah((total - given).clamp(0, total))}',
      };
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey('customer-${state.customer?.uid}'),
            initialValue: state.customer?.uid,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pelanggan'),
            items: [
              const DropdownMenuItem(value: null, child: Text('UMUM')),
              for (final c in customers) DropdownMenuItem(value: c.uid, child: Text(c.displayName)),
            ],
            onChanged: (uid) => vm.setCustomer(customers.where((c) => c.uid == uid).firstOrNull),
          ),
          TextField(
            controller: _sales,
            decoration: const InputDecoration(labelText: 'Nama sales (opsional)'),
            onChanged: vm.setSalesName,
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  controller: _discount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Diskon nota', suffixText: _discountPercent ? '%' : 'Rp'),
                  onChanged: (_) => _applyDiscount(),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: false, label: Text('Rp')), ButtonSegment(value: true, label: Text('%'))],
                selected: {_discountPercent},
                onSelectionChanged: (s) {
                  setState(() => _discountPercent = s.first);
                  _applyDiscount();
                },
              ),
            ],
          ),
          TotalsTable(totals: totals),
          DropdownButtonFormField<PaymentMethod>(
            key: ValueKey(state.method),
            initialValue: state.method,
            decoration: const InputDecoration(labelText: 'Metode bayar'),
            items: [for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(m.label))],
            onChanged: (m) => vm.setMethod(m ?? PaymentMethod.cash),
          ),
          if (!state.method.isCashless)
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: switch (state.method) {
                  PaymentMethod.cash => 'Uang diterima (Rp)',
                  PaymentMethod.downPayment => 'Nominal DP (Rp)',
                  _ => 'Dibayar sekarang (Rp, boleh 0)',
                },
              ),
              onChanged: (v) => vm.setAmountGiven(parseRupiah(v)),
            ),
          if (paymentInfo != null) Text(paymentInfo, style: Theme.of(context).textTheme.titleSmall),
          FilledButton.icon(
            onPressed: state.lines.isEmpty || state.submission.isLoading ? null : _checkout,
            icon: const Icon(Icons.point_of_sale),
            label: Text('Simpan ${formatRupiah(total)}'),
          ),
          if (state.lines.any((l) => l.priceType == PriceType.manual))
            Text('Ada harga manual: tercatat di log audit.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
