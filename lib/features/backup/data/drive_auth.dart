import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';

/// Izin akses Google Drive owner (scope `drive.file`).
class DriveAuth {
  static const scopes = ['https://www.googleapis.com/auth/drive.file'];

  Future<void>? _init;

  bool get configured {
    if (!AppConfig.googleDriveEnabled) return false;
    if (kIsWeb) return AppConfig.googleWebClientId.isNotEmpty;
    if (defaultTargetPlatform == TargetPlatform.iOS) return AppConfig.googleIosClientId.isNotEmpty;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  Future<void> _ready() => _init ??= GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? AppConfig.googleWebClientId
        : defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.googleIosClientId
        : null,
  );

  /// Token tanpa menampilkan apa pun; null bila owner perlu menekan tombol dulu
  /// (di web token hanya bertahan ±1 jam dan selama tab terbuka).
  Future<String?> silentToken() async {
    if (!configured) return null;
    await _ready();
    return (await GoogleSignIn.instance.authorizationClient.authorizationForScopes(scopes))?.accessToken;
  }

  /// Menampilkan pilihan akun Google / persetujuan. Panggil hanya dari tombol.
  Future<String> interactiveToken() async {
    await _ready();
    return (await GoogleSignIn.instance.authorizationClient.authorizeScopes(scopes)).accessToken;
  }
}
