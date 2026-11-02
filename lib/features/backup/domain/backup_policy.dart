import 'package:equatable/equatable.dart';

enum BackupKind {
  /// Backup harian otomatis (atau "Backup sekarang"); satu per hari.
  daily('harian'),

  /// Dibuat otomatis tepat sebelum backup lain di-load, agar load bisa dibatalkan.
  safety('sebelum-load');

  const BackupKind(this.slug);

  final String slug;
}

/// Identitas satu file backup, dibaca dari nama filenya sehingga lokal dan Drive
/// bisa dicocokkan tanpa membuka isinya.
class BackupInfo extends Equatable {
  const BackupInfo({required this.tenantId, required this.kind, required this.stamp});

  final String tenantId;
  final BackupKind kind;

  /// `yyyyMMdd-HHmmss` dalam WIB.
  final String stamp;

  /// `yyyyMMdd` (WIB).
  String get day => stamp.substring(0, 8);

  DateTime get createdAt => DateTime(
    int.parse(stamp.substring(0, 4)),
    int.parse(stamp.substring(4, 6)),
    int.parse(stamp.substring(6, 8)),
    int.parse(stamp.substring(9, 11)),
    int.parse(stamp.substring(11, 13)),
    int.parse(stamp.substring(13, 15)),
  );

  String get fileName => 'mpos-$tenantId-${kind.slug}-$stamp.json.gz';

  static final _pattern = RegExp(r'^mpos-(.+)-(harian|sebelum-load)-(\d{8}-\d{6})\.json\.gz$');

  /// null bila nama file bukan backup mPOS.
  static BackupInfo? parse(String fileName) {
    final m = _pattern.firstMatch(fileName);
    if (m == null) return null;
    return BackupInfo(
      tenantId: m.group(1)!,
      kind: BackupKind.values.firstWhere((k) => k.slug == m.group(2)),
      stamp: m.group(3)!,
    );
  }

  @override
  List<Object?> get props => [tenantId, kind, stamp];
}

/// Aturan jadwal & jumlah simpanan backup. Tidak bergantung Flutter/Firebase.
abstract final class BackupPolicy {
  /// Hari ini + 3 hari ke belakang.
  static const keepDaily = 4;
  static const keepSafety = 2;

  /// Waktu WIB (UTC+7) tanpa bergantung zona waktu perangkat.
  static DateTime wib(DateTime now) {
    final t = now.toUtc().add(const Duration(hours: 7));
    return DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second);
  }

  static String stampOf(DateTime now) {
    final t = wib(now);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }

  /// Backup harian jatuh tempo bila belum ada backup harian untuk hari ini (WIB),
  /// yaitu sejak pukul 00.00 WIB.
  static bool isDailyDue(DateTime now, String tenantId, Iterable<BackupInfo> existing) {
    final today = stampOf(now).substring(0, 8);
    return !existing.any((b) => b.tenantId == tenantId && b.kind == BackupKind.daily && b.day == today);
  }

  /// Backup yang harus dihapus: harian disisakan satu (terbaru) per hari untuk
  /// [keepDaily] hari terakhir; cadangan sebelum-load disisakan [keepSafety].
  static List<BackupInfo> toPrune(Iterable<BackupInfo> all, String tenantId) {
    final mine = all.where((b) => b.tenantId == tenantId).toList()..sort((a, b) => b.stamp.compareTo(a.stamp));
    final prune = <BackupInfo>[];
    final days = <String>{};
    var safety = 0;
    for (final b in mine) {
      switch (b.kind) {
        case BackupKind.daily:
          if (days.contains(b.day) || days.length >= keepDaily) {
            prune.add(b);
          } else {
            days.add(b.day);
          }
        case BackupKind.safety:
          if (++safety > keepSafety) prune.add(b);
      }
    }
    return prune;
  }
}
