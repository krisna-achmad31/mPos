import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/theme/theme_mode_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  if (!DefaultFirebaseOptions.isConfigured) {
    runApp(const FirebaseSetupApp());
    return;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(FirebaseSetupApp(error: e));
    return;
  }
  final savedThemeMode = await _savedThemeMode();
  runApp(
    ProviderScope(
      // Tampilan yang dipilih pengguna dibaca lebih dulu supaya aplikasi
      // langsung terbuka dengan tema yang benar.
      overrides: [
        themeModeProvider.overrideWith(
          () => ThemeModeController(initial: themeModeFromName(savedThemeMode)),
        ),
      ],
      child: const MposApp(),
    ),
  );
}

/// Baca pilihan tampilan tersimpan dari perangkat.
Future<String?> _savedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(themeModeStorageKey);
  } catch (_) {
    // Penyimpanan lokal tidak tersedia: pakai bawaan (ikuti sistem).
    return null;
  }
}
