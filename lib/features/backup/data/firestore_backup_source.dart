import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/firebase/collections.dart';
import '../../../core/firebase/tenant_store.dart';
import '../domain/backup_groups.dart';
import 'backup_codec.dart';
import 'backup_service.dart';

/// Membaca seluruh data distributor menjadi [BackupSnapshot] dan menuliskannya kembali.
class FirestoreBackupSource implements BackupData {
  FirestoreBackupSource(this._store);

  final TenantStore _store;

  FirebaseFirestore get _db => _store.db;

  /// Subkoleksi yang berada di bawah dokumen koleksi tertentu.
  static const _nested = {
    Collections.premiumCodes: [Collections.redemptions],
  };

  /// Firestore membatasi 500 operasi per batch.
  static const _batchLimit = 400;

  @override
  String get tenantId => _store.root.id;

  @override
  Future<Uint8List> exportBytes(DateTime now) async => BackupCodec.encode(await export(now));

  @override
  BackupSummary inspect(Uint8List bytes) {
    final s = BackupCodec.decode(bytes, db: _db);
    if (s.tenantPath != _store.root.path) {
      throw const AppException('Backup ini milik distributor lain dan tidak bisa di-load di sini.');
    }
    return (createdAt: s.createdAt, documentCount: s.documentCount);
  }

  @override
  Future<void> restoreBytes(Uint8List bytes, Set<BackupGroup> groups) =>
      restore(BackupCodec.decode(bytes, db: _db), groups);

  Query<Map<String, dynamic>> get _users =>
      _db.collection(Collections.users).where('distributorId', isEqualTo: _store.root.id);

  Future<BackupSnapshot> export(DateTime now) async {
    final root = await _store.root.get();
    final collections = <String, List<BackupDoc>>{};
    for (final name in BackupGroup.allCollections) {
      collections[name] = await _readCollection(_store.col(name), _nested[name] ?? const []);
    }
    final users = await _users.get();
    return BackupSnapshot(
      tenantPath: _store.root.path,
      createdAt: now,
      root: root.data(),
      collections: collections,
      users: [for (final d in users.docs) BackupDoc(d.id, d.data())],
    );
  }

  Future<List<BackupDoc>> _readCollection(CollectionReference<Map<String, dynamic>> col, List<String> nested) async {
    final snap = await col.get();
    return [
      for (final d in snap.docs)
        BackupDoc(d.id, d.data(), {
          for (final sub in nested) sub: await _readCollection(d.reference.collection(sub), const []),
        }),
    ];
  }

  /// Mengganti isi grup [groups] persis seperti di [snapshot]: dokumen yang tidak ada
  /// di backup dihapus, sisanya ditimpa. Akun pengguna hanya ditimpa (tidak dihapus)
  /// supaya akun yang dibuat setelah backup tetap bisa masuk.
  Future<void> restore(BackupSnapshot snapshot, Set<BackupGroup> groups) async {
    if (snapshot.tenantPath != _store.root.path) {
      throw const AppException('Backup ini milik distributor lain dan tidak bisa di-load di sini.');
    }
    final writer = _BatchWriter(_db, _batchLimit);
    for (final group in groups) {
      for (final name in group.collections) {
        await _replaceCollection(
          writer,
          _store.col(name),
          snapshot.collections[name] ?? const [],
          _nested[name] ?? const [],
        );
      }
      if (group == BackupGroup.settings && snapshot.root != null) {
        writer.set(_store.root, snapshot.root!);
      }
      if (group == BackupGroup.users) {
        for (final u in snapshot.users) {
          writer.set(_db.collection(Collections.users).doc(u.id), u.data);
        }
      }
    }
    await writer.flush();
  }

  Future<void> _replaceCollection(
    _BatchWriter writer,
    CollectionReference<Map<String, dynamic>> col,
    List<BackupDoc> docs,
    List<String> nested,
  ) async {
    final keep = {for (final d in docs) d.id};
    final current = await col.get();
    for (final d in current.docs) {
      if (keep.contains(d.id)) continue;
      for (final sub in nested) {
        await _replaceCollection(writer, d.reference.collection(sub), const [], const []);
      }
      writer.delete(d.reference);
    }
    for (final d in docs) {
      writer.set(col.doc(d.id), d.data);
      for (final sub in nested) {
        await _replaceCollection(writer, col.doc(d.id).collection(sub), d.subcollections[sub] ?? const [], const []);
      }
    }
  }
}

class _BatchWriter {
  _BatchWriter(this._db, this._limit);

  final FirebaseFirestore _db;
  final int _limit;
  final _pending = <void Function(WriteBatch)>[];

  void set(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data) =>
      _pending.add((b) => b.set(ref, data));

  void delete(DocumentReference<Map<String, dynamic>> ref) => _pending.add((b) => b.delete(ref));

  Future<void> flush() async {
    for (var i = 0; i < _pending.length; i += _limit) {
      final batch = _db.batch();
      for (final op in _pending.skip(i).take(_limit)) {
        op(batch);
      }
      await batch.commit();
    }
    _pending.clear();
  }
}
