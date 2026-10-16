import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/product_picker.dart';
import '../../../../core/widgets/quantity_dialog.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../pricing/domain/services/pricing_service.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../domain/entities/cart_line.dart';
import '../../domain/services/sale_calculator.dart';
import '../viewmodels/pos_view_model.dart';
import '../widgets/line_text.dart';
import '../widgets/totals_table.dart';

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

    return PageScaffold(
      title: 'Kasir',
      subtitle: 'Pilih produk, atur jumlah, lalu catat pembayaran.',
      scrollable: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return const Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _CartPanel()),
                SizedBox(width: AppSpacing.lg),
                SizedBox(width: 380, child: SingleChildScrollView(child: _PaymentPanel())),
              ],
            );
          }
          return const SingleChildScrollView(
            child: Column(
              children: [
                _CartPanel(shrinkWrap: true),
                SizedBox(height: AppSpacing.lg),
                _PaymentPanel(),
              ],
            ),
          );
        },
      ),
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
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Keranjang masih kosong',
              message: 'Scan barcode atau cari produk untuk menambah barang.',
            ),
          )
        : ListView.separated(
            shrinkWrap: widget.shrinkWrap,
            physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
            padding: EdgeInsets.zero,
            itemCount: state.lines.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final line = state.lines[i];
              final discount = priced[i].discountAmount;
              final product = _productOf(line.productId);
              return _CartLineTile(
                line: line,
                discount: discount,
                discountLabel: priced[i].discountLabel,
                onDecrease: product == null ? null : () => vm.setQty(i, line.qty - 1, product),
                onIncrease: product == null ? null : () => vm.setQty(i, line.qty + 1, product),
                onQuantity: product == null
                    ? null
                    : () async {
                        final qty = await askQuantity(context, current: line.qty, unit: line.unit);
                        if (qty != null) vm.setQty(i, qty, product);
                      },
                onManual: () => _manualPrice(i, line),
                onRemove: () => vm.removeLine(i),
              );
            },
          );

    return SectionCard(
      title: 'Keranjang',
      subtitle: 'Pesanan saat ini',
      trailing: StatusBadge('${state.lines.length} item', tone: BadgeTone.neutral),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProductPicker(
            key: ValueKey(_pickerKey),
            label: 'Scan barcode / cari produk',
            onSelected: (p) {
              vm.addProduct(p);
              setState(() => _pickerKey++);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (widget.shrinkWrap) list else Expanded(child: list),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.discount,
    required this.discountLabel,
    required this.onDecrease,
    required this.onIncrease,
    required this.onQuantity,
    required this.onManual,
    required this.onRemove,
  });

  final CartLine line;
  final int discount;
  final String discountLabel;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onQuantity;
  final VoidCallback onManual;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return InkWell(
      onLongPress: onManual,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    line.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: tokens.ink),
                  ),
                  Text(
                    [
                      '${lineDetail(line)} (${line.priceType.label})',
                      if (discount > 0) '$discountLabel −${formatRupiah(discount)}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _QtyButton(icon: Icons.remove, tooltip: 'Kurangi', onPressed: onDecrease),
                      TextButton(
                        onPressed: onQuantity,
                        child: Text('${line.qty}', style: theme.textTheme.titleSmall),
                      ),
                      _QtyButton(icon: Icons.add, tooltip: 'Tambah', onPressed: onIncrease),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  formatRupiah(line.gross - discount),
                  style: theme.textTheme.titleSmall?.copyWith(color: tokens.ink),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opsi baris',
                  icon: Icon(Icons.more_vert, size: 18, color: tokens.muted),
                  onSelected: (v) => v == 'manual' ? onManual() : onRemove(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'manual', child: Text('Harga manual')),
                    PopupMenuItem(value: 'remove', child: Text('Hapus')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: tokens.canvas,
        foregroundColor: tokens.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final total = totals.total;
    final given = state.amountGiven;

    final (String? paymentInfo, BadgeTone? paymentTone) = total > 0
        ? switch (state.method) {
            PaymentMethod.cash => given >= total
                ? ('Kembalian ${formatRupiah(given - total)}', BadgeTone.success)
                : ('Uang kurang ${formatRupiah(total - given)}', BadgeTone.danger),
            PaymentMethod.transfer || PaymentMethod.qris => ('Dianggap lunas', BadgeTone.success),
            PaymentMethod.downPayment || PaymentMethod.credit =>
              ('Sisa tagihan ${formatRupiah((total - given).clamp(0, total))}', BadgeTone.warning),
          }
        : (null, null);

    final Color noticeFg = paymentTone == BadgeTone.danger
        ? tokens.danger
        : paymentTone == BadgeTone.warning
            ? tokens.warning
            : tokens.success;
    final Color noticeBg = paymentTone == BadgeTone.danger
        ? tokens.dangerTint
        : paymentTone == BadgeTone.warning
            ? tokens.warningTint
            : tokens.successTint;
    final IconData noticeIcon = switch (paymentTone) {
      BadgeTone.danger => Icons.error_outline,
      BadgeTone.warning => Icons.schedule,
      _ => Icons.check_circle_outline,
    };

    return SectionCard(
      title: 'Pembayaran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          KpiRow(
            children: [
              KpiTile(
                label: 'Total pesanan',
                value: formatRupiah(total),
                hint: '${state.lines.length} item',
                icon: Icons.receipt_long_outlined,
                highlight: true,
                width: null,
              ),
            ],
          ),
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
            spacing: AppSpacing.sm,
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
          if (paymentInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: noticeBg,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Row(
                spacing: AppSpacing.sm,
                children: [
                  Icon(noticeIcon, size: 18, color: noticeFg),
                  Expanded(
                    child: Text(
                      paymentInfo,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: noticeFg),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: state.lines.isEmpty || state.submission.isLoading ? null : _checkout,
            icon: const Icon(Icons.point_of_sale),
            label: Text('Terima pembayaran · ${formatRupiah(total)}'),
          ),
          if (state.lines.any((l) => l.priceType == PriceType.manual))
            Text('Ada harga manual: tercatat di log audit.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
