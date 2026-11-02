import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/viewmodel/action_view_model.dart';
import '../../backup_providers.dart';
import '../../data/backup_service.dart';
import '../../domain/backup_groups.dart';

class AutoBackupState {
  const AutoBackupState({this.last, this.error, this.running = false});

  /// Backup terakhir yang dibuat selama aplikasi terbuka.
  final BackupRunResult? last;
  final String? error;
  final bool running;
}

/// Backup harian otomatis selama aplikasi owner terbuka: dicek saat dibuka dan
/// tiap 10 menit, sehingga backup tetap dibuat walau aplikasi terbuka melewati 00.00 WIB.
class AutoBackupViewModel extends Notifier<AutoBackupState> {
  static const interval = Duration(minutes: 10);

  @override
  AutoBackupState build() {
    final timer = Timer.periodic(interval, (_) => check());
    // Beri waktu layar pertama selesai dimuat sebelum membaca seluruh data.
    final first = Timer(const Duration(seconds: 5), check);
    ref.onDispose(() {
      timer.cancel();
      first.cancel();
    });
    return const AutoBackupState();
  }

  Future<void> check() async {
    if (state.running) return;
    state = AutoBackupState(last: state.last, running: true);
    try {
      final result = await ref.read(backupServiceProvider).runDailyIfDue();
      if (!ref.mounted) return;
      state = AutoBackupState(last: result ?? state.last);
      if (result != null) ref.invalidate(backupListProvider);
    } catch (e) {
      if (ref.mounted) state = AutoBackupState(last: state.last, error: '$e');
    }
  }
}

final autoBackupProvider = NotifierProvider<AutoBackupViewModel, AutoBackupState>(AutoBackupViewModel.new);

final backupListProvider = FutureProvider.autoDispose((ref) => ref.watch(backupServiceProvider).list());

/// Aksi dari halaman Backup data. [lastMessage] berisi ringkasan untuk ditampilkan.
class BackupActionsViewModel extends ActionViewModel {
  String? lastMessage;

  /// Keterangan proses yang sedang berjalan, ditampilkan selama tombol nonaktif.
  String busyLabel = '';

  Future<bool> _run(String label, Future<void> Function() action) {
    busyLabel = label;
    return run(action);
  }

  Future<bool> backupNow() => _run('Membuat backup seluruh data…', () async {
    final r = await ref.read(backupServiceProvider).backupNow(interactiveDrive: true);
    lastMessage = 'Backup tersimpan di perangkat ini${_driveText(r.drive, r.driveError)}';
    ref.invalidate(backupListProvider);
  });

  Future<bool> syncToDrive() => _run('Mengupload backup ke Google Drive…', () async {
    final (status, error) = await ref.read(backupServiceProvider).syncToDrive();
    if (status == DriveStatus.failed) throw AppException(error ?? 'Upload ke Google Drive gagal.');
    lastMessage = 'Backup di perangkat ini sudah ada di Google Drive';
    ref.invalidate(backupListProvider);
  });

  Future<Uint8List?> read(BackupEntry entry) async {
    Uint8List? bytes;
    final ok = await _run(
      'Membuka file backup…',
      () async => bytes = await ref.read(backupServiceProvider).read(entry),
    );
    return ok ? bytes : null;
  }

  Future<bool> restore(Uint8List bytes, Set<BackupGroup> groups) =>
      _run('Mem-backup kondisi sekarang lalu me-load backup… Jangan tutup aplikasi.', () async {
        final safety = await ref.read(backupServiceProvider).restore(bytes, groups);
        lastMessage =
            'Backup berhasil di-load. Kondisi sebelum load disimpan sebagai backup '
            '"sebelum load"${_driveText(safety.drive, safety.driveError)}';
        ref.invalidate(backupListProvider);
      });

  static String _driveText(DriveStatus status, String? error) => switch (status) {
    DriveStatus.uploaded => ' dan Google Drive.',
    DriveStatus.notConfigured => '.',
    DriveStatus.needsConnect => '. Belum terupload ke Google Drive.',
    DriveStatus.failed => '. Upload ke Google Drive gagal: $error',
  };
}

final backupActionsProvider = NotifierProvider<BackupActionsViewModel, AsyncValue<void>>(BackupActionsViewModel.new);
