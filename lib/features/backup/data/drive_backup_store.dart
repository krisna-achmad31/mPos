import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/error/app_exception.dart';
import 'backup_service.dart';

/// Backup di folder "mPOS Backup" pada Google Drive owner, lewat Drive REST v3.
/// Memakai scope `drive.file`: aplikasi hanya bisa melihat file yang ia buat sendiri.
class DriveBackupStore implements RemoteBackupStore {
  DriveBackupStore(this._client, this._accessToken);

  static const folderName = 'mPOS Backup';
  static const _api = 'https://www.googleapis.com/drive/v3/files';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3/files';

  final http.Client _client;
  final String _accessToken;
  String? _folderId;

  Map<String, String> get _auth => {'Authorization': 'Bearer $_accessToken'};

  Future<Map<String, dynamic>> _json(http.Response r) async {
    if (r.statusCode >= 300) {
      throw AppException('Google Drive menolak permintaan (${r.statusCode}). Coba hubungkan ulang Google Drive.');
    }
    return r.body.isEmpty ? const {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _query(String q) async {
    final uri = Uri.parse(
      _api,
    ).replace(queryParameters: {'q': q, 'fields': 'files(id,name)', 'pageSize': '1000', 'spaces': 'drive'});
    final body = await _json(await _client.get(uri, headers: _auth));
    return (body['files'] as List? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<String> _folder() async {
    if (_folderId != null) return _folderId!;
    final found = await _query(
      "name = '$folderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
    );
    if (found.isNotEmpty) return _folderId = found.first['id'] as String;
    final created = await _json(
      await _client.post(
        Uri.parse(_api),
        headers: {..._auth, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': folderName, 'mimeType': 'application/vnd.google-apps.folder'}),
      ),
    );
    return _folderId = created['id'] as String;
  }

  @override
  Future<List<DriveFile>> list() async {
    final files = await _query("'${await _folder()}' in parents and trashed = false");
    return [for (final f in files) DriveFile(f['id'] as String, f['name'] as String)];
  }

  @override
  Future<void> upload(String name, Uint8List bytes) async {
    const boundary = 'mpos-backup-boundary';
    final meta = jsonEncode({
      'name': name,
      'parents': [await _folder()],
      'mimeType': 'application/gzip',
    });
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n'))
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/gzip\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    await _json(
      await _client.post(
        Uri.parse(_upload).replace(queryParameters: {'uploadType': 'multipart', 'fields': 'id'}),
        headers: {..._auth, 'Content-Type': 'multipart/related; boundary=$boundary'},
        body: body.takeBytes(),
      ),
    );
  }

  @override
  Future<Uint8List> download(String fileId) async {
    final r = await _client.get(Uri.parse('$_api/$fileId').replace(queryParameters: {'alt': 'media'}), headers: _auth);
    if (r.statusCode >= 300) throw AppException('Gagal mengunduh backup dari Google Drive (${r.statusCode}).');
    return r.bodyBytes;
  }

  @override
  Future<void> delete(String fileId) async {
    final r = await _client.delete(Uri.parse('$_api/$fileId'), headers: _auth);
    if (r.statusCode >= 300 && r.statusCode != 404) {
      throw AppException('Gagal menghapus backup lama di Google Drive (${r.statusCode}).');
    }
  }
}
