import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci penyimpanan pilihan tampilan di perangkat.
const themeModeStorageKey = 'mpos_theme_mode';

/// Ubah teks tersimpan menjadi [ThemeMode]. Tidak dikenal / kosong = ikuti sistem.
ThemeMode themeModeFromName(String? name) => switch (name) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// Nama tampilan untuk tiap mode (dipakai di menu & pengaturan).
String themeModeLabel(ThemeMode mode) => switch (mode) {
  ThemeMode.light => 'Terang',
  ThemeMode.dark => 'Gelap',
  ThemeMode.system => 'Ikuti sistem',
};

/// Ikon untuk tiap mode.
IconData themeModeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
  ThemeMode.system => Icons.brightness_auto_outlined,
};

/// Mode tampilan aplikasi: Terang, Gelap, atau Ikuti sistem.
///
/// Pilihan disimpan di perangkat lewat `shared_preferences`, jadi tetap sama
/// setelah aplikasi ditutup. Nilai awal dibaca di `main()` dan disuntikkan
/// lewat [initial] supaya tampilan tidak "berkedip" saat dibuka.
///
/// `design_ui.pen` digambar untuk versi terang; versi gelap memakai pemetaan
/// warna yang sama (lihat `AppTokens.dark`, `AppTheme.dark`).
class ThemeModeController extends Notifier<ThemeMode> {
  ThemeModeController({this.initial = ThemeMode.system});

  /// Mode yang dipakai saat aplikasi baru dibuka.
  final ThemeMode initial;

  @override
  ThemeMode build() => initial;

  /// Ganti mode lalu simpan pilihannya.
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeStorageKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  () => ThemeModeController(),
);
