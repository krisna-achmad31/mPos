/// Saklar global aplikasi.
abstract final class AppConfig {
  /// true = tanpa login: pengguna memilih role di layar awal.
  /// Ubah ke false untuk kembali memakai login Email/Password.
  static const demoMode = true;
}
