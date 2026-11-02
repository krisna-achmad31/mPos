import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/firebase/firebase_providers.dart';
import '../auth/auth_providers.dart';
import 'data/backup_service.dart';
import 'data/drive_auth.dart';
import 'data/drive_backup_store.dart';
import 'data/firestore_backup_source.dart';
import 'data/local_backup_store.dart';

final localBackupStoreProvider = Provider<LocalBackupStore>((ref) => LocalBackupStore());

final driveAuthProvider = Provider<DriveAuth>((ref) => DriveAuth());

/// Backup selalu untuk data distributor milik owner.
final backupServiceProvider = Provider<BackupService>((ref) {
  final auth = ref.watch(driveAuthProvider);
  final client = http.Client();
  ref.onDispose(client.close);
  return BackupService(
    data: FirestoreBackupSource(ref.watch(distributorStoreProvider)),
    local: ref.watch(localBackupStoreProvider),
    openDrive: ({required interactive}) async {
      final token = interactive ? await auth.interactiveToken() : await auth.silentToken();
      return token == null ? null : DriveBackupStore(client, token);
    },
    driveConfigured: auth.configured,
    clock: ref.watch(clockProvider),
  );
});
