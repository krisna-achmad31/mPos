import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';

/// Satu dokumen beserta subkoleksinya (mis. `premium_codes/{id}/redemptions`).
class BackupDoc {
  const BackupDoc(this.id, this.data, [this.subcollections = const {}]);

  final String id;
  final Map<String, dynamic> data;
  final Map<String, List<BackupDoc>> subcollections;
}

/// Isi lengkap satu backup.
class BackupSnapshot {
  const BackupSnapshot({
    required this.tenantPath,
    required this.createdAt,
    required this.root,
    required this.collections,
    required this.users,
  });

  /// `distributors/{id}`; load ditolak bila berbeda dengan tenant yang sedang dibuka.
  final String tenantPath;
  final DateTime createdAt;
  final Map<String, dynamic>? root;
  final Map<String, List<BackupDoc>> collections;
  final List<BackupDoc> users;

  int get documentCount {
    int count(List<BackupDoc> docs) =>
        docs.fold(0, (n, d) => n + 1 + d.subcollections.values.fold(0, (m, s) => m + count(s)));
    return collections.values.fold(0, (n, docs) => n + count(docs)) + users.length + (root == null ? 0 : 1);
  }
}

/// Mengubah [BackupSnapshot] ke file `.json.gz` dan sebaliknya.
/// Tipe khusus Firestore (Timestamp, GeoPoint, referensi, blob) disimpan bertanda `__t`
/// agar kembali persis sama saat di-load.
abstract final class BackupCodec {
  static const format = 'mpos-backup';
  static const version = 1;

  static Uint8List encode(BackupSnapshot s) {
    final json = {
      'format': format,
      'version': version,
      'tenantPath': s.tenantPath,
      'createdAt': s.createdAt.toUtc().toIso8601String(),
      'root': s.root == null ? null : encodeValue(s.root),
      'collections': {for (final e in s.collections.entries) e.key: e.value.map(_encodeDoc).toList()},
      'users': s.users.map(_encodeDoc).toList(),
    };
    return GZipEncoder().encodeBytes(utf8.encode(jsonEncode(json)));
  }

  static BackupSnapshot decode(List<int> bytes, {required FirebaseFirestore db}) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes))) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException('File bukan backup mPOS atau sudah rusak.');
    }
    if (json['format'] != format) throw const AppException('File bukan backup mPOS.');
    if ((json['version'] as num? ?? 0) > version) {
      throw const AppException('Backup dibuat oleh versi aplikasi yang lebih baru. Perbarui aplikasi dulu.');
    }
    List<BackupDoc> docs(Object? list) => [for (final d in (list as List? ?? const [])) _decodeDoc(d as Map, db)];
    return BackupSnapshot(
      tenantPath: json['tenantPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      root: json['root'] == null ? null : decodeValue(json['root'], db) as Map<String, dynamic>,
      collections: {for (final e in (json['collections'] as Map? ?? const {}).entries) e.key as String: docs(e.value)},
      users: docs(json['users']),
    );
  }

  static Map<String, dynamic> _encodeDoc(BackupDoc d) => {
    'id': d.id,
    'data': encodeValue(d.data),
    if (d.subcollections.isNotEmpty)
      'sub': {for (final e in d.subcollections.entries) e.key: e.value.map(_encodeDoc).toList()},
  };

  static BackupDoc _decodeDoc(Map json, FirebaseFirestore db) =>
      BackupDoc(json['id'] as String, decodeValue(json['data'], db) as Map<String, dynamic>, {
        for (final e in (json['sub'] as Map? ?? const {}).entries)
          e.key as String: [for (final d in e.value as List) _decodeDoc(d as Map, db)],
      });

  static Object? encodeValue(Object? v) => switch (v) {
    Timestamp t => {'__t': 'ts', 's': t.seconds, 'n': t.nanoseconds},
    GeoPoint g => {'__t': 'geo', 'lat': g.latitude, 'lng': g.longitude},
    DocumentReference r => {'__t': 'ref', 'p': r.path},
    Blob b => {'__t': 'blob', 'b': base64Encode(b.bytes)},
    Map m => {for (final e in m.entries) e.key as String: encodeValue(e.value)},
    List l => [for (final x in l) encodeValue(x)],
    _ => v,
  };

  static Object? decodeValue(Object? v, FirebaseFirestore db) {
    if (v is List) return [for (final x in v) decodeValue(x, db)];
    if (v is! Map) return v;
    return switch (v['__t']) {
      'ts' => Timestamp((v['s'] as num).toInt(), (v['n'] as num).toInt()),
      'geo' => GeoPoint((v['lat'] as num).toDouble(), (v['lng'] as num).toDouble()),
      'ref' => db.doc(v['p'] as String),
      'blob' => Blob(base64Decode(v['b'] as String)),
      _ => <String, dynamic>{for (final e in v.entries) e.key as String: decodeValue(e.value, db)},
    };
  }
}
