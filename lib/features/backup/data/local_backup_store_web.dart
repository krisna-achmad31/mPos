import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../../core/error/app_exception.dart';
import 'local_backup_store.dart';

/// Backup lokal di IndexedDB browser (cukup besar untuk file backup, tidak seperti localStorage).
class PlatformLocalBackupStore implements LocalBackupStore {
  static const _dbName = 'mpos_backups';
  static const _storeName = 'files';

  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> _open() => _db ??= () {
    final request = web.window.indexedDB.open(_dbName, 1);
    request.onupgradeneeded = ((web.Event _) {
      (request.result as web.IDBDatabase).createObjectStore(_storeName);
    }).toJS;
    return _await(request).then((r) => r as web.IDBDatabase);
  }();

  Future<web.IDBObjectStore> _objects(String mode) async =>
      (await _open()).transaction(_storeName.toJS, mode).objectStore(_storeName);

  static Future<JSAny?> _await(web.IDBRequest request) {
    final done = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) => done.complete(request.result)).toJS;
    request.onerror = ((web.Event _) => done.completeError(
      AppException('Penyimpanan browser gagal: ${request.error?.message ?? 'tidak diketahui'}'),
    )).toJS;
    return done.future;
  }

  @override
  Future<List<String>> list() async {
    final keys = await _await((await _objects('readonly')).getAllKeys());
    return [for (final k in (keys as JSArray<JSString>).toDart) k.toDart];
  }

  @override
  Future<void> save(String name, Uint8List bytes) async {
    await _await((await _objects('readwrite')).put(bytes.toJS, name.toJS));
  }

  @override
  Future<Uint8List?> read(String name) async {
    final value = await _await((await _objects('readonly')).get(name.toJS));
    return value == null ? null : (value as JSUint8Array).toDart;
  }

  @override
  Future<void> delete(String name) async {
    await _await((await _objects('readwrite')).delete(name.toJS));
  }
}
