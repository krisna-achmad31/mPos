import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/dates.dart';
import '../../data/backup_service.dart';
import '../../domain/backup_groups.dart';

/// Konfirmasi load backup: ganti semua data atau hanya bagian tertentu.
/// Mengembalikan grup yang dipilih, atau null bila dibatalkan.
class RestoreDialog extends StatefulWidget {
  const RestoreDialog({super.key, required this.summary});

  final BackupSummary summary;

  static Future<Set<BackupGroup>?> show(BuildContext context, BackupSummary summary) => showDialog<Set<BackupGroup>>(
    context: context,
    builder: (_) => RestoreDialog(summary: summary),
  );

  @override
  State<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<RestoreDialog> {
  bool _all = true;
  final _groups = <BackupGroup>{};
  bool _understood = false;

  Set<BackupGroup> get _selected => _all ? BackupGroup.values.toSet() : _groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final when = formatDateTime(widget.summary.createdAt.toLocal());
    return AlertDialog(
      title: const Text('Load backup?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text('Backup $when · ${widget.summary.documentCount} dokumen data.'),
              const SizedBox(height: 8),
              RadioGroup<bool>(
                groupValue: _all,
                onChanged: (v) => setState(() => _all = v ?? true),
                child: const Column(
                  children: [
                    RadioListTile(value: true, contentPadding: EdgeInsets.zero, title: Text('Ganti semua data')),
                    RadioListTile(value: false, contentPadding: EdgeInsets.zero, title: Text('Sebagian saja')),
                  ],
                ),
              ),
              if (!_all)
                for (final g in BackupGroup.values)
                  CheckboxListTile(
                    value: _groups.contains(g),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 16),
                    title: Text(g.label),
                    onChanged: (v) => setState(() => v == true ? _groups.add(g) : _groups.remove(g)),
                  ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tokens.dangerTint, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  [
                    _all
                        ? 'PERINGATAN: SEMUA data distributor akan diganti dengan isi backup ini.'
                        : 'PERINGATAN: data di bagian yang dipilih akan diganti dengan isi backup ini.',
                    'Semua transaksi, stok masuk, dan perubahan setelah $when di bagian tersebut akan HILANG.',
                    if (!_all)
                      'Load sebagian bisa membuat data tidak cocok, mis. stok produk tidak sesuai riwayat nota. '
                          'Bila ragu, pilih "Ganti semua data".',
                    'Kondisi sekarang otomatis di-backup dulu (jenis "Sebelum load") agar bisa dikembalikan.',
                  ].join('\n\n'),
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.danger),
                ),
              ),
              CheckboxListTile(
                value: _understood,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Saya mengerti dan ingin melanjutkan'),
                onChanged: (v) => setState(() => _understood = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: _understood && _selected.isNotEmpty ? () => Navigator.pop(context, _selected) : null,
          child: Text(_all ? 'Ganti semua data' : 'Load bagian terpilih'),
        ),
      ],
    );
  }
}
