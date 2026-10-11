/// Error yang pesannya aman ditampilkan langsung ke pengguna.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}
