import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_shell.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../domain/cafe_rules.dart';
import '../cafe_view_models.dart';

/// Owner distributor: terbitkan kode promo premium POS kopi dan pantau pelanggan yang memakainya.
class PremiumCodesView extends ConsumerWidget {
  const PremiumCodesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(leading: shellMenuButton(context), title: const Text('Premium POS Kopi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _CodeDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Kode promo'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Pelanggan memakai kode di menu POS Kopi untuk mengaktifkan premium. '
              'Satu kode hanya bisa dipakai sekali per pelanggan.',
            ),
          ),
          ListTile(title: Text('Kode promo', style: text.titleMedium)),
          AsyncValueView(
            value: ref.watch(premiumCodesProvider),
            data: (codes) => codes.isEmpty
                ? const EmptyState(icon: Icons.redeem, message: 'Belum ada kode promo')
                : Column(
                    children: [
                      for (final c in codes)
                        ListTile(
                          leading: Icon(Icons.confirmation_number_outlined, color: c.usable ? null : Theme.of(context).disabledColor),
                          title: SelectableText(c.code, style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
                          subtitle: Text([
                            '${c.days} hari',
                            c.isUnlimited ? 'dipakai ${c.used}×' : 'dipakai ${c.used}/${c.maxUses}',
                            if (c.note.isNotEmpty) c.note,
                            if (c.isExhausted) 'kuota habis',
                          ].join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Salin kode',
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: c.code));
                                  showMessage(context, 'Kode ${c.code} disalin');
                                },
                              ),
                              Switch(
                                value: c.active,
                                onChanged: (v) => ref.read(cafeActionsViewModelProvider.notifier).setCodeActive(c, v),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 32),
          ListTile(title: Text('Pelanggan dengan POS Kopi', style: text.titleMedium)),
          AsyncValueView(
            value: ref.watch(distributorCafesProvider),
            data: (cafes) => cafes.isEmpty
                ? const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada pelanggan yang memakai POS Kopi.'))
                : Column(
                    children: [
                      for (final cafe in cafes)
                        ListTile(
                          leading: const Icon(Icons.local_cafe_outlined),
                          title: Text(cafe.name),
                          subtitle: Text(
                            cafe.premiumUntil == null
                                ? 'Belum premium · stok dari pesanan sudah tersinkron'
                                : '${cafe.isPremium(now) ? 'Premium s/d' : 'Berakhir'} ${formatDate(cafe.premiumUntil!)}'
                                    '${cafe.lastCode.isEmpty ? '' : ' · kode ${cafe.lastCode}'}',
                          ),
                          trailing: cafe.isPremium(now)
                              ? Chip(label: const Text('Aktif'), backgroundColor: Theme.of(context).colorScheme.primaryContainer)
                              : null,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CodeDialog extends ConsumerStatefulWidget {
  const _CodeDialog();

  static Future<void> show(BuildContext context) => showDialog(context: context, builder: (_) => const _CodeDialog());

  @override
  ConsumerState<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends ConsumerState<_CodeDialog> {
  static const _durations = [7, 30, 90, 365];

  late final _code = TextEditingController(text: _randomCode());
  final _maxUses = TextEditingController();
  final _note = TextEditingController();
  int _days = 30;
  String? _error;

  /// Mis. KOPI-7K2Q (tanpa huruf mirip seperti O/0, I/1).
  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return 'KOPI${List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join()}';
  }

  @override
  void dispose() {
    _code.dispose();
    _maxUses.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = PremiumCode(
      code: CafeRules.normalizeCode(_code.text),
      days: _days,
      maxUses: int.tryParse(_maxUses.text) ?? 0,
      note: _note.text,
    );
    final ok = await ref.read(cafeActionsViewModelProvider.notifier).createCode(code);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showMessage(context, 'Kode ${code.code} dibuat');
    } else {
      setState(() => _error = '${ref.read(cafeActionsViewModelProvider).error}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    return AlertDialog(
      title: const Text('Kode promo baru'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Kode',
                helperText: 'Huruf & angka saja',
                suffixIcon: IconButton(
                  tooltip: 'Acak',
                  icon: const Icon(Icons.casino_outlined),
                  onPressed: () => setState(() => _code.text = _randomCode()),
                ),
              ),
            ),
            Text('Lama premium', style: Theme.of(context).textTheme.labelLarge),
            SegmentedButton<int>(
              segments: [for (final d in _durations) ButtonSegment(value: d, label: Text(d == 365 ? '1 thn' : '$d hr'))],
              selected: {_days},
              onSelectionChanged: (v) => setState(() => _days = v.first),
            ),
            TextField(
              controller: _maxUses,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Kuota pemakaian', helperText: 'Kosongkan = tanpa batas'),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan', hintText: 'mis. promo pelanggan baru')),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: busy ? null : _save, child: const Text('Buat')),
      ],
    );
  }
}
