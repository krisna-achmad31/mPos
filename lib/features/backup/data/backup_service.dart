import 'dart:typed_data';

import '../domain/backup_groups.dart';
import '../domain/backup_policy.dart';
import 'local_backup_store.dart';

typedef BackupSummary = ({DateTime createdAt, int documentCount});

/// Sumber data yang di-backup (Firestore di aplikasi, palsu di test).
abstract interface class BackupData {
  String get tenantId;
  Future<Uint8List> exportBytes(DateTime now);

  /// Memvalidasi file (format & milik distributor ini) tanpa menulis apa pun.
  BackupSummary inspect(Uint8List bytes);
  Future<void> restoreBytes(Uint8List bytes, Set<BackupGroup> groups);
}

class DriveFile {
  const DriveFile(this.id, this.name);

  final String id;
  final String name;
}

/// Penyimpanan cloud (Google Drive).
abstract interface class RemoteBackupStore {
  Future<List<DriveFile>> list();
  Future<void> upload(String name, Uint8List bytes);
  Future<Uint8List> download(String fileId);
  Future<void> delete(String fileId);
}

/// Membuka Drive; null bila belum dikonfigurasi atau owner perlu menekan tombol dulu.
typedef RemoteOpener = Future<RemoteBackupStore?> Function({required bool interactive});

enum DriveStatus {
  uploaded,

  /// Google Drive belum diatur di [AppConfig].
  notConfigured,

  /// Perlu menekan "Upload ke Google Drive" (izin Drive belum ada / sudah kedaluwarsa).
  needsConnect,
  failed,
}

/// Satu backup yang ada di perangkat ini, di Drive, atau keduanya.
class BackupEntry {
  const BackupEntry(this.info, {required this.local, this.driveId});

  final BackupInfo info;
  final bool local;
  final String? driveId;
}

class BackupRunResult {
  const BackupRunResult(this.info, this.drive, [this.driveError]);

  final BackupInfo info;
  final DriveStatus drive;
  final String? driveError;
}

/// Membuat, menyimpan (lokal + Drive), merapikan, dan me-load backup.
class BackupService {
  BackupService({
    required this._data,
    required this._local,
    required this._openDrive,
    required this._driveConfigured,
    required this._clock,
  });

  final BackupData _data;
  final LocalBackupStore _local;
  final RemoteOpener _openDrive;
  final bool _driveConfigured;
  final DateTime Function() _clock;

  String get tenantId => _data.tenantId;

  Future<List<BackupInfo>> _localInfos() async =>
      [for (final n in await _local.list()) ?BackupInfo.parse(n)].where((b) => b.tenantId == tenantId).toList();

  /// Semua backup milik distributor ini, terbaru dulu. Drive ikut dibaca bila
  /// izinnya sudah ada tanpa perlu menekan tombol.
  Future<({List<BackupEntry> entries, bool driveListed})> list() async {
    final byName = <String, BackupEntry>{for (final b in await _localInfos()) b.fileName: BackupEntry(b, local: true)};
    RemoteBackupStore? drive;
    try {
      drive = await _openDrive(interactive: false);
    } catch (_) {
      drive = null;
    }
    if (drive != null) {
      for (final f in await drive.list()) {
        final info = BackupInfo.parse(f.name);
        if (info == null || info.tenantId != tenantId) continue;
        byName[f.name] = BackupEntry(info, local: byName.containsKey(f.name), driveId: f.id);
      }
    }
    final entries = byName.values.toList()..sort((a, b) => b.info.stamp.compareTo(a.info.stamp));
    return (entries: entries, driveListed: drive != null);
  }

  /// Backup harian otomatis: hanya bila hari ini (WIB) belum ada backup harian di perangkat ini.
  Future<BackupRunResult?> runDailyIfDue() async {
    if (!BackupPolicy.isDailyDue(_clock(), tenantId, await _localInfos())) return null;
    return backupNow();
  }

  Future<BackupRunResult> backupNow({BackupKind kind = BackupKind.daily, bool interactiveDrive = false}) async {
    final now = _clock();
    final info = BackupInfo(tenantId: tenantId, kind: kind, stamp: BackupPolicy.stampOf(now));
    final bytes = await _data.exportBytes(now);
    await _local.save(info.fileName, bytes);
    await _pruneLocal();
    final (drive, error) = await _toDrive({info.fileName: bytes}, interactive: interactiveDrive);
    return BackupRunResult(info, drive, error);
  }

  /// Mengunggah backup lokal yang belum ada di Drive (mis. dibuat saat izin web kedaluwarsa).
  Future<(DriveStatus, String?)> syncToDrive({bool interactive = true}) async {
    final pending = <String, Uint8List>{};
    for (final b in await _localInfos()) {
      final bytes = await _local.read(b.fileName);
      if (bytes != null) pending[b.fileName] = bytes;
    }
    return _toDrive(pending, interactive: interactive);
  }

  Future<(DriveStatus, String?)> _toDrive(Map<String, Uint8List> files, {required bool interactive}) async {
    if (!_driveConfigured) return (DriveStatus.notConfigured, null);
    try {
      final drive = await _openDrive(interactive: interactive);
      if (drive == null) return (DriveStatus.needsConnect, null);
      final existing = {for (final f in await drive.list()) f.name};
      // Yang sudah pasti akan dirapikan tidak perlu diunggah.
      final pruned = BackupPolicy.toPrune([
        ...existing.map(BackupInfo.parse).nonNulls,
        ...files.keys.map(BackupInfo.parse).nonNulls,
      ], tenantId).map((b) => b.fileName).toSet();
      for (final e in files.entries) {
        if (!existing.contains(e.key) && !pruned.contains(e.key)) await drive.upload(e.key, e.value);
      }
      final now = await drive.list();
      final prune = BackupPolicy.toPrune(
        now.map((f) => BackupInfo.parse(f.name)).nonNulls,
        tenantId,
      ).map((b) => b.fileName).toSet();
      for (final f in now.where((f) => prune.contains(f.name))) {
        await drive.delete(f.id);
      }
      return (DriveStatus.uploaded, null);
    } catch (e) {
      return (DriveStatus.failed, '$e');
    }
  }

  Future<void> _pruneLocal() async {
    for (final b in BackupPolicy.toPrune(await _localInfos(), tenantId)) {
      await _local.delete(b.fileName);
    }
  }

  Future<Uint8List> read(BackupEntry entry) async {
    if (entry.local) {
      final bytes = await _local.read(entry.info.fileName);
      if (bytes != null) return bytes;
    }
    final drive = entry.driveId == null ? null : await _openDrive(interactive: true);
    if (drive == null) throw StateError('Backup ${entry.info.fileName} tidak ditemukan.');
    return drive.download(entry.driveId!);
  }

  BackupSummary inspect(Uint8List bytes) => _data.inspect(bytes);

  /// Load backup. Kondisi sekarang selalu di-backup dulu (jenis "sebelum-load")
  /// sehingga load yang keliru bisa dibatalkan dengan me-load backup itu.
  Future<BackupRunResult> restore(Uint8List bytes, Set<BackupGroup> groups) async {
    _data.inspect(bytes);
    final safety = await backupNow(kind: BackupKind.safety);
    await _data.restoreBytes(bytes, groups);
    return safety;
  }
}
