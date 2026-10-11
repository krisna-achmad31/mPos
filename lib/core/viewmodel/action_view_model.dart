import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Basis ViewModel untuk aksi satu kali (simpan, hapus, proses).
/// State-nya `AsyncValue<void>`: View cukup memantau loading dan error.
abstract class ActionViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  /// Menjalankan [action] dan mengembalikan true bila sukses.
  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}
