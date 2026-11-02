import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/core/error/app_exception.dart';
import 'package:mpos/features/backup/data/backup_service.dart';
import 'package:mpos/features/backup/data/local_backup_store.dart';
import 'package:mpos/features/backup/domain/backup_groups.dart';
import 'package:mpos/features/backup/domain/backup_policy.dart';

class _Data implements BackupData {
  final log = <String>[];
  var version = 0;

  @override
  String get tenantId => 't1';

  @override
  Future<Uint8List> exportBytes(DateTime now) async {
    log.add('export');
    return Uint8List.fromList([++version]);
  }

  @override
  BackupSummary inspect(Uint8List bytes) {
    if (bytes.isEmpty) throw const AppException('rusak');
    return (createdAt: DateTime(2026), documentCount: 1);
  }

  @override
  Future<void> restoreBytes(Uint8List bytes, Set<BackupGroup> groups) async => log.add('restore ${bytes.first}');
}

class _Memory implements LocalBackupStore {
  final files = <String, Uint8List>{};

  @override
  Future<List<String>> list() async => files.keys.toList();
  @override
  Future<void> save(String name, Uint8List bytes) async => files[name] = bytes;
  @override
  Future<Uint8List?> read(String name) async => files[name];
  @override
  Future<void> delete(String name) async => files.remove(name);
}

class _Drive implements RemoteBackupStore {
  final files = <String, Uint8List>{};

  @override
  Future<List<DriveFile>> list() async => [for (final n in files.keys) DriveFile('id-$n', n)];
  @override
  Future<void> upload(String name, Uint8List bytes) async => files[name] = bytes;
  @override
  Future<Uint8List> download(String fileId) async => files[fileId.substring(3)]!;
  @override
  Future<void> delete(String fileId) async => files.remove(fileId.substring(3));
}

void main() {
  late _Data data;
  late _Memory local;
  late _Drive drive;
  late DateTime now;
  var driveAuthorized = true;

  BackupService service({bool configured = true}) => BackupService(
    data: data,
    local: local,
    openDrive: ({required interactive}) async => driveAuthorized || interactive ? drive : null,
    driveConfigured: configured,
    clock: () => now,
  );

  setUp(() {
    data = _Data();
    local = _Memory();
    drive = _Drive();
    driveAuthorized = true;
    now = DateTime.utc(2026, 11, 1, 17, 5); // 00.05 WIB, 2 Nov
  });

  test('backup harian dibuat sekali per hari dan hanya 4 hari tersimpan di lokal & Drive', () async {
    final s = service();
    for (var day = 0; day < 6; day++) {
      final r = await s.runDailyIfDue();
      expect(r?.drive, DriveStatus.uploaded);
      expect(await s.runDailyIfDue(), isNull, reason: 'hari yang sama tidak dibackup dua kali');
      now = now.add(const Duration(days: 1));
    }
    expect(data.log.where((l) => l == 'export'), hasLength(6));
    final days = local.files.keys.map((n) => BackupInfo.parse(n)!.day).toList()..sort();
    expect(days, ['20261104', '20261105', '20261106', '20261107']);
    expect(drive.files.keys.toSet(), local.files.keys.toSet());
  });

  test('tanpa izin Drive backup tetap tersimpan lokal lalu bisa disusulkan', () async {
    driveAuthorized = false;
    final s = service();
    final r = await s.runDailyIfDue();
    expect(r!.drive, DriveStatus.needsConnect);
    expect(local.files, hasLength(1));
    expect(drive.files, isEmpty);
    final (status, _) = await s.syncToDrive();
    expect(status, DriveStatus.uploaded);
    expect(drive.files.keys, local.files.keys);
  });

  test('Drive belum dikonfigurasi: hanya lokal', () async {
    final r = await service(configured: false).backupNow();
    expect(r.drive, DriveStatus.notConfigured);
    expect(local.files, hasLength(1));
  });

  test('daftar menggabungkan lokal dan Drive', () async {
    final s = service();
    await s.backupNow();
    local.files.clear();
    now = now.add(const Duration(days: 1));
    driveAuthorized = false;
    await s.backupNow();
    driveAuthorized = true;
    final list = await s.list();
    expect(list.entries.map((e) => (e.local, e.driveId != null)), [(true, false), (false, true)]);
    expect(await s.read(list.entries.last), [1]);
  });

  test('load membuat cadangan kondisi sekarang dulu; file rusak ditolak tanpa menulis', () async {
    final s = service();
    await expectLater(s.restore(Uint8List(0), {BackupGroup.stock}), throwsA(isA<AppException>()));
    expect(data.log, isEmpty);
    final safety = await s.restore(Uint8List.fromList([42]), BackupGroup.values.toSet());
    expect(data.log, ['export', 'restore 42']);
    expect(safety.info.kind, BackupKind.safety);
    expect(local.files.keys.single, contains('sebelum-load'));
  });
}
