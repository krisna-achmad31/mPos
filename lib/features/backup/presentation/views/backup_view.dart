import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../backup_providers.dart';
import '../../data/backup_service.dart';
import '../../domain/backup_policy.dart';
import '../viewmodels/backup_view_model.dart';
import 'restore_dialog.dart';

/// Backup harian seluruh data distributor dan load kembali (khusus Owner).
class BackupView extends ConsumerWidget {
  const BackupView({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<bool> Function() action) async {
    final ok = await action();
    if (context.mounted) await _afterAction(context, ref, ok);
  }

  Future<void> _afterAction(BuildContext context, WidgetRef ref, bool ok) async {
    if (!context.mounted) return;
    final vm = ref.read(backupActionsProvider.notifier);
    showMessage(context, ok ? vm.lastMessage ?? 'Selesai' : '${ref.read(backupActionsProvider).error}', isError: !ok);
  }

  Future<void> _load(BuildContext context, WidgetRef ref, Uint8List bytes) async {
    final service = ref.read(backupServiceProvider);
    final BackupSummary summary;
    try {
      summary = service.inspect(bytes);
    } catch (e) {
      showMessage(context, '$e', isError: true);
      return;
    }
    final groups = await RestoreDialog.show(context, summary);
    if (groups == null || !context.mounted) return;
    final ok = await ref.read(backupActionsProvider.notifier).restore(bytes, groups);
    if (context.mounted) await _afterAction(context, ref, ok);
  }

  Future<void> _loadEntry(BuildContext context, WidgetRef ref, BackupEntry entry) async {
    final bytes = await ref.read(backupActionsProvider.notifier).read(entry);
    if (!context.mounted) return;
    if (bytes == null) return _afterAction(context, ref, false);
    await _load(context, ref, bytes);
  }

  Future<void> _loadFile(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['gz']);
    if (file == null) return;
    final bytes = await file.xFile.readAsBytes();
    if (context.mounted) await _load(context, ref, bytes);
  }

  Future<void> _download(BuildContext context, WidgetRef ref, BackupEntry entry) async {
    final bytes = await ref.read(backupActionsProvider.notifier).read(entry);
    if (bytes == null) {
      if (context.mounted) await _afterAction(context, ref, false);
      return;
    }
    await FilePicker.saveFile(
      fileName: entry.info.fileName,
      bytes: bytes,
      mimeType: 'application/gzip',
      type: FileType.custom,
      allowedExtensions: const ['gz'],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(backupActionsProvider).isLoading;
    final auto = ref.watch(autoBackupProvider);
    final driveConfigured = ref.watch(driveAuthProvider).configured;
    final vm = ref.read(backupActionsProvider.notifier);

    return PageScaffold(
      title: 'Backup data',
      subtitle: 'Semua data distributor: produk, stok, nota, pembayaran, pengeluaran, pengaturan, dan log.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Backup otomatis',
            subtitle:
                'Setiap hari mulai pukul 00.00 WIB, saat aplikasi Owner terbuka. '
                'Disimpan ${BackupPolicy.keepDaily} hari terakhir (hari ini + ${BackupPolicy.keepDaily - 1} hari ke belakang).',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.md,
              children: [
                _AutoStatus(state: auto),
                _DriveStatusLine(configured: driveConfigured),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Backup sekarang'),
                      onPressed: busy ? null : () => _run(context, ref, vm.backupNow),
                    ),
                    if (driveConfigured)
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add_to_drive_outlined),
                        label: const Text('Upload ke Google Drive'),
                        onPressed: busy ? null : () => _run(context, ref, vm.syncToDrive),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.file_open_outlined),
                      label: const Text('Load dari file'),
                      onPressed: busy ? null : () => _loadFile(context, ref),
                    ),
                  ],
                ),
                if (busy) _BusyNote(label: vm.busyLabel),
              ],
            ),
          ),
          SectionCard(
            title: 'Daftar backup',
            subtitle: 'Pilih Load untuk mengembalikan data. Kondisi sekarang selalu di-backup dulu sebelum load.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (busy) _BusyNote(label: vm.busyLabel),
                AsyncValueView(
                  value: ref.watch(backupListProvider),
                  data: (result) => result.entries.isEmpty
                      ? const EmptyState(icon: Icons.history, message: 'Belum ada backup. Tekan "Backup sekarang".')
                      : Column(
                          children: [
                            for (final entry in result.entries)
                              _BackupRow(
                                entry: entry,
                                busy: busy,
                                onLoad: () => _loadEntry(context, ref, entry),
                                onDownload: () => _download(context, ref, entry),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Penjelasan kenapa tombol sedang nonaktif.
class _BusyNote extends StatelessWidget {
  const _BusyNote({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        const LinearProgressIndicator(),
        Text('$label Tombol aktif lagi setelah selesai.', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _AutoStatus extends StatelessWidget {
  const _AutoStatus({required this.state});

  final AutoBackupState state;

  @override
  Widget build(BuildContext context) {
    final last = state.last;
    final text = state.running
        ? 'Memeriksa / membuat backup hari ini…'
        : state.error != null
        ? 'Backup otomatis gagal: ${state.error}'
        : last != null
        ? 'Backup otomatis dibuat ${formatDateTime(last.info.createdAt)} WIB.'
        : 'Backup hari ini akan dibuat otomatis bila belum ada di perangkat ini.';
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: state.error != null ? context.tokens.danger : null),
    );
  }
}

class _DriveStatusLine extends StatelessWidget {
  const _DriveStatusLine({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Text(
      configured
          ? 'Google Drive: file disimpan di folder "mPOS Backup". Di versi web, izin Google Drive berlaku ±1 jam; '
                'bila backup otomatis belum terupload, tekan "Upload ke Google Drive".'
          : 'Google Drive belum diaktifkan untuk aplikasi ini, jadi backup hanya disimpan di perangkat ini. '
                'Unduh file backup secara berkala sebagai cadangan.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.entry, required this.busy, required this.onLoad, required this.onDownload});

  final BackupEntry entry;
  final bool busy;
  final VoidCallback onLoad;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = entry.info;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  '${formatDateTime(info.createdAt)} WIB',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    StatusBadge(
                      info.kind == BackupKind.daily ? 'Harian' : 'Sebelum load',
                      tone: info.kind == BackupKind.daily ? BadgeTone.neutral : BadgeTone.warning,
                    ),
                    if (entry.local) const StatusBadge('Perangkat ini', tone: BadgeTone.success),
                    if (entry.driveId != null) const StatusBadge('Google Drive', tone: BadgeTone.success),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Unduh file backup',
            icon: const Icon(Icons.download_outlined),
            onPressed: busy ? null : onDownload,
          ),
          FilledButton.tonal(onPressed: busy ? null : onLoad, child: const Text('Load')),
        ],
      ),
    );
  }
}
