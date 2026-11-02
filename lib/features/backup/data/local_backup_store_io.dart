import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'local_backup_store.dart';

class PlatformLocalBackupStore implements LocalBackupStore {
  Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/mpos_backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _file(String name) async => File('${(await _dir()).path}/$name');

  @override
  Future<List<String>> list() async => [
    await for (final f in (await _dir()).list())
      if (f is File) f.uri.pathSegments.last,
  ];

  @override
  Future<void> save(String name, Uint8List bytes) async {
    // Tulis ke file sementara dulu agar backup lama tidak rusak bila aplikasi tertutup di tengah jalan.
    final tmp = await _file('$name.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename((await _file(name)).path);
  }

  @override
  Future<Uint8List?> read(String name) async {
    final file = await _file(name);
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> delete(String name) async {
    final file = await _file(name);
    if (await file.exists()) await file.delete();
  }
}
