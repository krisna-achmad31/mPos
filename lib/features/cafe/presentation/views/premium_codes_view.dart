import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../cafe_providers.dart';
import '../../domain/cafe.dart';
import '../../domain/cafe_rules.dart';
import '../cafe_view_models.dart';

/// Owner distributor: terbitkan kode promo premium POS kopi dan pantau
/// pelanggan yang memakainya (padanan frame `40 · Owner / Premium POS Kopi`).
class PremiumCodesView extends ConsumerWidget {
  const PremiumCodesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final now = DateTime.now();
    final isPhone = context.deviceClass == DeviceClass.phone;

    return PageScaffold(
      title: 'Premium POS Kopi',
      subtitle: 'Terbitkan kode promo dan pantau pelanggan yang mengaktifkan premium.',
      actions: [
        FilledButton.icon(
          onPressed: () => _CodeDialog.show(context),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Buat kode'),
        ),
      ],
      scrollable: false,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SectionCard(
            title: 'Kode promo',
            subtitle: 'Pelanggan memakai kode di menu POS Kopi untuk mengaktifkan premium. '
                'Satu kode hanya bisa dipakai sekali per pelanggan.',
            child: AsyncValueView(
              value: ref.watch(premiumCodesProvider),
              data: (codes) {
                if (codes.isEmpty) {
                  return const EmptyState(icon: Icons.redeem, message: 'Belum ada kode promo', title: 'Belum ada kode');
                }
                if (isPhone) {
                  return Column(
                    children: [
                      for (final c in codes)
                        _CodeRow(code: c, onCopy: () => _copy(context, c.code), onActive: (v) => _setActive(ref, c, v)),
                    ],
                  );
                }
                return AppDataTable(
                  columns: const ['Kode', 'Masa aktif', 'Pemakaian', 'Catatan', 'Status', 'Aksi'],
                  flex: const [3, 2, 2, 3, 2, 2],
                  rows: [
                    for (final c in codes)
                      [
                        SelectableText(
                          c.code,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1),
                        ),
                        Text('${c.days} hari'),
                        Text(c.isUnlimited ? 'dipakai ${c.used}×' : 'dipakai ${c.used}/${c.maxUses}'),
                        Text(c.note.isEmpty ? '—' : c.note, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Align(alignment: Alignment.centerLeft, child: _CodeStatus(code: c)),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Salin kode',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () => _copy(context, c.code),
                              ),
                              Switch(
                                value: c.active,
                                onChanged: (v) => _setActive(ref, c, v),
                              ),
                            ],
                          ),
                        ),
                      ],
                  ],
                );
              },
            ),
          ),
          SectionCard(
            title: 'Pelanggan dengan POS Kopi',
            subtitle: 'Kedai yang sudah mengaktifkan premium.',
            child: AsyncValueView(
              value: ref.watch(distributorCafesProvider),
              data: (cafes) {
                if (cafes.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('Belum ada pelanggan yang memakai POS Kopi.', style: theme.textTheme.bodySmall),
                  );
                }
                return Column(
                  children: [
                    for (final cafe in cafes)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: tokens.primaryTint,
                            borderRadius: BorderRadius.circular(AppRadius.tile),
                          ),
                          child: Icon(Icons.local_cafe_outlined, size: 20, color: theme.colorScheme.primary),
                        ),
                        title: Text(cafe.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          cafe.premiumUntil == null
                              ? 'Belum premium · stok dari pesanan sudah tersinkron'
                              : '${cafe.isPremium(now) ? 'Premium s/d' : 'Berakhir'} ${formatDate(cafe.premiumUntil!)}'
                                  '${cafe.lastCode.isEmpty ? '' : ' · kode ${cafe.lastCode}'}',
                        ),
                        trailing: cafe.isPremium(now)
                            ? const StatusBadge('Premium', tone: BadgeTone.success, icon: Icons.workspace_premium_outlined)
                            : const StatusBadge('Standar', tone: BadgeTone.neutral),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    showMessage(context, 'Kode $code disalin');
  }

  void _setActive(WidgetRef ref, PremiumCode code, bool value) =>
      ref.read(cafeActionsViewModelProvider.notifier).setCodeActive(code, value);
}

class _CodeStatus extends StatelessWidget {
  const _CodeStatus({required this.code});

  final PremiumCode code;

  @override
  Widget build(BuildContext context) {
    if (code.isExhausted) {
      return const StatusBadge('Habis', tone: BadgeTone.danger, icon: Icons.block);
    }
    return StatusBadge(
      code.active ? 'Aktif' : 'Nonaktif',
      tone: code.active ? BadgeTone.success : BadgeTone.neutral,
    );
  }
}

/// Satu kode promo untuk tata letak HP.
class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.code, required this.onCopy, required this.onActive});

  final PremiumCode code;
  final VoidCallback onCopy;
  final ValueChanged<bool> onActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        spacing: AppSpacing.md,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Flexible(
                      child: SelectableText(
                        code.code,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                    ),
                    _CodeStatus(code: code),
                  ],
                ),
                Text(
                  [
                    '${code.days} hari',
                    code.isUnlimited ? 'dipakai ${code.used}×' : 'dipakai ${code.used}/${code.maxUses}',
                    if (code.note.isNotEmpty) code.note,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Salin kode',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: onCopy,
          ),
          Switch(value: code.active, onChanged: onActive),
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
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final busy = ref.watch(cafeActionsViewModelProvider).isLoading;
    return AlertDialog(
      title: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(Icons.confirmation_number_outlined, size: 20, color: theme.colorScheme.primary),
          const Flexible(child: Text('Kode promo baru')),
        ],
      ),
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
            Text('Lama premium', style: theme.textTheme.labelLarge),
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
            if (_error != null) Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger)),
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
