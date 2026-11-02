import 'package:flutter_test/flutter_test.dart';
import 'package:mpos/features/backup/domain/backup_policy.dart';

BackupInfo daily(String stamp, [String tenant = 't1']) =>
    BackupInfo(tenantId: tenant, kind: BackupKind.daily, stamp: stamp);

void main() {
  test('nama file bolak-balik dan tanggal dalam WIB', () {
    final info = daily('20261102-000312');
    expect(info.fileName, 'mpos-t1-harian-20261102-000312.json.gz');
    expect(BackupInfo.parse(info.fileName), info);
    expect(BackupInfo.parse('foto.png'), isNull);
    // 17.30 UTC = 00.30 WIB hari berikutnya.
    expect(BackupPolicy.stampOf(DateTime.utc(2026, 11, 1, 17, 30)), '20261102-003000');
  });

  test('backup harian jatuh tempo mulai 00.00 WIB, sekali per hari', () {
    final existing = [daily('20261101-000500')];
    // 23.59 WIB tanggal 1: sudah ada backup hari itu.
    expect(BackupPolicy.isDailyDue(DateTime.utc(2026, 11, 1, 16, 59), 't1', existing), isFalse);
    // 00.00 WIB tanggal 2: jatuh tempo.
    expect(BackupPolicy.isDailyDue(DateTime.utc(2026, 11, 1, 17, 0), 't1', existing), isTrue);
    // Backup distributor lain tidak dihitung.
    expect(BackupPolicy.isDailyDue(DateTime.utc(2026, 11, 1, 16, 59), 't2', existing), isTrue);
  });

  test('menyisakan 4 hari terakhir, satu (terbaru) per hari, dan 2 cadangan sebelum-load', () {
    final all = [
      for (var d = 1; d <= 6; d++) daily('202611${d.toString().padLeft(2, '0')}-000100'),
      daily('20261106-153000'),
      for (var i = 1; i <= 3; i++) BackupInfo(tenantId: 't1', kind: BackupKind.safety, stamp: '2026110$i-120000'),
      daily('20261101-000100', 't2'),
    ];
    final pruned = BackupPolicy.toPrune(all, 't1').map((b) => b.stamp).toSet();
    expect(pruned, {
      '20261106-000100', // kalah dengan backup tanggal 6 yang lebih baru
      '20261102-000100',
      '20261101-000100',
      '20261101-120000', // cadangan ketiga terlama
    });
    expect(BackupPolicy.toPrune(all, 't2'), isEmpty);
  });
}
