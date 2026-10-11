// Web sudah terkonfigurasi (app "mPOS Web").
// Android & iOS masih placeholder — jalankan:
//   flutterfire configure --project=mpos-da4b9 --platforms=android,ios
// Catatan: API key web Firebase memang publik; keamanan dijaga Firestore rules.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const projectId = 'mpos-da4b9';

  /// false sampai `flutterfire configure` dijalankan.
  static bool get isConfigured => !currentPlatform.apiKey.startsWith('TODO');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError('Platform ini belum dikonfigurasi untuk Firebase.'),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyB596tYSa_3q_qnuhNNPoLWuru9oFm1cfE',
    appId: '1:303351182728:web:db649744f844db77b3363d',
    messagingSenderId: '303351182728',
    projectId: projectId,
    authDomain: 'mpos-da4b9.firebaseapp.com',
    storageBucket: 'mpos-da4b9.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'TODO-run-flutterfire-configure',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: projectId,
    storageBucket: '$projectId.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'TODO-run-flutterfire-configure',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: projectId,
    storageBucket: '$projectId.firebasestorage.app',
    iosBundleId: 'com.mpos.mpos',
  );
}
