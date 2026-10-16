import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/product_image_view.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/auth_providers.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/product_providers.dart';
import '../../../sales/domain/entities/cart_line.dart';
import '../../../sales/domain/services/sale_calculator.dart';
import '../../../settings/settings_providers.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../cafe_view_models.dart';

/// Kasir POS kopi: pilih menu, bayar, struk tercetak. Stok bahan terpotong sesuai resep.
class CafePosView extends ConsumerStatefulWidget {
  const CafePosView({super.key});

  @override
  ConsumerState<CafePosView> createState() => _CafePosViewState();
}

class _CafePosViewState extends ConsumerState<CafePosView> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final cart = ref.watch(cafeCartProvider);
    final isOwner = ref.watch(currentUserProvider).role == UserRole.cafeOwner;
    final cafeName = ref.watch(myCafeProvider).value?.name ?? '';
    final cashier = ref.watch(currentUserProvider).displayName;

    final menu = AsyncValueView(
      value: ref.watch(activeProductsProvider),
      data: (menus) {
        if (menus.isEmpty) {
          return EmptyState(
            icon: Icons.menu_book_outlined,
            message: isOwner ? 'Belum ada menu. Tambahkan di Menu & resep.' : 'Belum ada menu. Minta Owner menambahkan menu.',
          );
        }
        final categories = {for (final m in menus) m.category}.where((c) => c.isNotEmpty).toList()..sort();
        final shown = menus.where((m) => m.matches(_query) && (_category == null || m.category == _category)).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari menu', isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (categories.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  children: [
                    for (final c in [null, ...categories])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c ?? 'Semua'),
                          selected: _category == c,
                          selectedColor: tokens.primaryTint,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(child: _MenuGrid(menus: shown)),
          ],
        );
      },
    );

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        leading: shellMenuButton(context),
        title: Row(
          spacing: 6,
          children: [
            Text('POS Kopi', style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
            Text(
              '/  Kasir',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: tokens.ink,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Riwayat struk',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.go('/cafe/receipts'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: wide
          ? Padding(
              padding: AppSpacing.pageWide,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHeading(
                    title: cafeName.isEmpty ? 'Kasir' : 'Kasir $cafeName',
                    subtitle: 'Pilih menu dan sesuaikan pesanan pelanggan.',
                    actions: [StatusBadge('Kasir: $cashier', tone: BadgeTone.info)],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: menu),
                        VerticalDivider(width: 1, color: tokens.line),
                        SizedBox(width: 360, child: _CartPanel()),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${cafeName.isEmpty ? 'Kopi' : cafeName} · Kasir $cashier',
                      style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  ),
                ),
                Expanded(child: menu),
              ],
            ),
      bottomNavigationBar: wide || cart.isEmpty ? null : const _CartBar(),
    );
  }
}

class _MenuGrid extends ConsumerWidget {
  const _MenuGrid({required this.menus});

  final List<Product> menus;

  /// Porsi yang masih bisa dibuat dari stok bahan; null = menu tanpa resep.
  static int? portions(Recipe? recipe, Map<String, Ingredient> ingredients) {
    if (recipe == null || recipe.isEmpty) return null;
    var result = 1 << 30;
    for (final l in recipe.lines) {
      final i = ingredients[l.ingredientId];
      if (i == null || l.qty <= 0) return 0;
      result = min(result, max(0, (i.stock / l.qty).floor()));
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final primary = theme.colorScheme.primary;
    final cart = {for (final l in ref.watch(cafeCartProvider)) l.productId: l.qty};
    final recipes = ref.watch(recipesProvider).value ?? const {};
    final ingredients = ref.watch(ingredientMapProvider);
    final allowNegative = ref.watch(cafeSettingsProvider).value?.allowNegativeStock ?? false;

    if (menus.isEmpty) return const EmptyState(icon: Icons.search_off, message: 'Menu tidak ditemukan');
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.7,
      ),
      itemCount: menus.length,
      itemBuilder: (context, index) {
        final m = menus[index];
        final inCart = cart[m.id] ?? 0;
        final left = portions(recipes[m.id], ingredients);
        final soldOut = left != null && left - inCart <= 0 && !allowNegative;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: inCart > 0 ? primary : tokens.line, width: inCart > 0 ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: theme.colorScheme.surface,
            child: InkWell(
              onTap: soldOut ? null : () => ref.read(cafeCartProvider.notifier).add(m),
              child: Opacity(
                opacity: soldOut ? 0.45 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ProductImageView(imageBase64: m.imageBase64, fallbackIcon: Icons.local_cafe_outlined, borderRadius: 0),
                          if (inCart > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  '$inCart',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (m.category.isNotEmpty)
                            Text(m.category, style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted)),
                          const SizedBox(height: 2),
                          Text(
                            formatRupiah(m.sellPrice),
                            style: theme.textTheme.titleSmall?.copyWith(color: primary, fontWeight: FontWeight.w700),
                          ),
                          if (left != null)
                            Text(
                              soldOut ? 'Bahan habis' : 'Sisa ±${left - inCart} porsi',
                              style: theme.textTheme.labelSmall?.copyWith(color: soldOut ? tokens.danger : tokens.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ringkasan keranjang di bawah layar (HP); ketuk untuk membuka keranjang.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cafeCartProvider);
    final count = cart.fold(0, (s, l) => s + l.qty);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: _CartPanel(inSheet: true)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_bag_outlined),
              const SizedBox(width: AppSpacing.sm),
              Text('$count item'),
              const Spacer(),
              Text(formatRupiah(SaleCalculator.totals(cart).subtotal)),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({this.inSheet = false});

  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final cart = ref.watch(cafeCartProvider);
    final vm = ref.read(cafeCartProvider.notifier);
    final tax = ref.watch(storeSettingsProvider).value?.effectiveTax ?? 0;
    final totals = SaleCalculator.totals(cart, taxPercent: tax);
    final shortages = ref.watch(cafeCartShortagesProvider);
    final allowNegative = ref.watch(cafeSettingsProvider).value?.allowNegativeStock ?? false;
    final blocked = shortages.isNotEmpty && !allowNegative;

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: Text('Pesanan baru', style: theme.textTheme.titleSmall)),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: vm.clear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Kosongkan'),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.line),
          Expanded(
            child: cart.isEmpty
                ? const EmptyState(icon: Icons.local_cafe_outlined, message: 'Ketuk menu untuk menambah pesanan')
                : ListView(children: [for (final l in cart) _CartRow(line: l)]),
          ),
          if (shortages.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: tokens.warningTint, borderRadius: BorderRadius.circular(AppRadius.control)),
              child: Text(
                '${allowNegative ? 'Stok bahan tercatat kurang (tetap bisa dijual)' : 'Stok bahan kurang'}: ${shortages.join('; ')}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.warning),
              ),
            ),
          Divider(height: 1, color: tokens.line),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.sm,
              children: [
                if (totals.tax > 0) ...[
                  _amount(context, 'Subtotal', totals.subtotal),
                  _amount(context, 'Pajak ${totals.taxPercent}%', totals.tax),
                ],
                Row(
                  children: [
                    Text('Total', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(formatRupiah(totals.total), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: cart.isEmpty || blocked
                      ? null
                      : () async {
                          final paid = await _PaymentDialog.show(context, total: totals.total);
                          if (paid && inSheet && context.mounted) Navigator.pop(context);
                        },
                  icon: const Icon(Icons.payments_outlined),
                  label: Text('Bayar ${formatRupiah(totals.total)}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amount(BuildContext context, String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(formatRupiah(value), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}

class _CartRow extends ConsumerWidget {
  const _CartRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final vm = ref.read(cafeCartProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  '${formatRupiah(line.unitPrice)} · ${formatRupiah(line.gross)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => vm.setQty(line.productId, line.qty - 1),
          ),
          Text('${line.qty}', style: theme.textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => vm.setQty(line.productId, line.qty + 1),
          ),
        ],
      ),
    );
  }
}

/// Pembayaran: tunai (dengan kembalian), QRIS, atau transfer. Mengembalikan true bila struk tersimpan.
class _PaymentDialog extends ConsumerStatefulWidget {
  const _PaymentDialog({required this.total});

  final int total;

  static Future<bool> show(BuildContext context, {required int total}) async =>
      await showDialog<bool>(context: context, builder: (_) => _PaymentDialog(total: total)) ?? false;

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  static const _methods = [PaymentMethod.cash, PaymentMethod.qris, PaymentMethod.transfer];

  final _name = TextEditingController();
  final _cash = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _cash.dispose();
    super.dispose();
  }

  /// Pecahan uang yang wajar untuk total ini, mis. 23.000 -> 25rb, 30rb, 50rb, 100rb.
  List<int> get _suggestions {
    final t = widget.total;
    final result = <int>{t};
    for (final step in [5000, 10000, 50000, 100000]) {
      result.add(((t + step - 1) ~/ step) * step);
    }
    return result.toList()..sort();
  }

  Future<void> _pay() async {
    final given = _method == PaymentMethod.cash ? parseRupiah(_cash.text) : 0;
    if (_method == PaymentMethod.cash && given < widget.total) {
      setState(() => _error = 'Uang tunai kurang dari total.');
      return;
    }
    final vm = ref.read(cafeActionsViewModelProvider.notifier);
    final ok = await vm.checkout(customerName: _name.text, method: _method, amountGiven: given);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = '${ref.read(cafeActionsViewModelProvider).error}');
      return;
    }
    final invoiceId = vm.lastInvoiceId!;
    final change = _method == PaymentMethod.cash ? given - widget.total : 0;
    // Dialog segera ditutup: ambil semua yang dibutuhkan untuk mencetak sebelum widget ini dibuang.
    final messenger = ScaffoldMessenger.of(context);
    final printer = ref.read(receiptPrintViewModelProvider.notifier);
    final autoPrint = (ref.read(cafeSettingsProvider).value ?? const CafeSettings()).autoPrint;
    Future<void> print() async {
      if (!await printer.printById(invoiceId)) {
        messenger.showSnackBar(SnackBar(content: Text('Struk tersimpan, tapi gagal dicetak: ${printer.errorText}')));
      }
    }

    Navigator.pop(context, true);
    if (autoPrint) print();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(change > 0 ? 'Transaksi tersimpan · kembalian ${formatRupiah(change)}' : 'Transaksi tersimpan'),
        action: autoPrint ? null : SnackBarAction(label: 'Cetak struk', onPressed: print),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    final given = parseRupiah(_cash.text);
    return AlertDialog(
      title: const Text('Pembayaran'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Text(formatRupiah(widget.total), textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama pemesan (opsional)', hintText: 'Untuk dipanggil saat pesanan siap'),
              ),
              SegmentedButton<PaymentMethod>(
                segments: [for (final m in _methods) ButtonSegment(value: m, label: Text(m.label))],
                selected: {_method},
                onSelectionChanged: (v) => setState(() {
                  _method = v.first;
                  _error = null;
                }),
              ),
              if (_method == PaymentMethod.cash) ...[
                TextField(
                  controller: _cash,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Uang diterima (Rp)'),
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _pay(),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _suggestions)
                      ActionChip(
                        label: Text(s == widget.total ? 'Uang pas' : formatRupiah(s)),
                        onPressed: () => setState(() => _cash.text = '$s'),
                      ),
                  ],
                ),
                if (given >= widget.total)
                  Text('Kembalian ${formatRupiah(given - widget.total)}', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              ] else
                Text(
                  _method == PaymentMethod.qris
                      ? 'Pastikan pembayaran QRIS sudah masuk sebelum menyimpan.'
                      : 'Pastikan transfer sudah diterima sebelum menyimpan.',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                ),
              if (_error != null) Text(_error!, style: TextStyle(color: tokens.danger)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          onPressed: busy ? null : _pay,
          child: Text(ref.watch(cafeSettingsProvider).value?.autoPrint ?? true ? 'Simpan & cetak' : 'Simpan'),
        ),
      ],
    );
  }
}
