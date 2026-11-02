/// Saklar global aplikasi.
abstract final class AppConfig {
  /// true = tanpa login: pengguna memilih role di layar awal.
  /// Ubah ke false untuk kembali memakai login Email/Password.
  static const demoMode = true;

  /// Backup ke Google Drive owner. Aktifkan setelah OAuth client dibuat di
  /// Google Cloud Console (lihat bagian "Backup data" di README).
  static const googleDriveEnabled = false;

  /// OAuth client ID tipe "Web application" (dipakai versi web).
  static const googleWebClientId = '';

  /// OAuth client ID tipe "iOS" (dipakai versi iOS). Android tidak butuh ID di sini,
  /// cukup SHA-1 aplikasi terdaftar di project Firebase / Google Cloud yang sama.
  static const googleIosClientId = '';
}
