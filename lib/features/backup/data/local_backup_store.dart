import 'dart:typed_data';

import 'local_backup_store_io.dart' if (dart.library.js_interop) 'local_backup_store_web.dart' as impl;

/// Penyimpanan backup di perangkat ini: folder aplikasi (Android/iOS) atau
/// IndexedDB browser (web). Bertahan saat aplikasi ditutup, tetapi hilang bila
/// aplikasi di-uninstall atau data situs di browser dihapus.
abstract interface class LocalBackupStore {
  factory LocalBackupStore() = impl.PlatformLocalBackupStore;

  Future<List<String>> list();
  Future<void> save(String name, Uint8List bytes);
  Future<Uint8List?> read(String name);
  Future<void> delete(String name);
}
