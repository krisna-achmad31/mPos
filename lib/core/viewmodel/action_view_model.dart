import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Basis ViewModel untuk aksi satu kali (simpan, hapus, proses).
/// State-nya `AsyncValue<void>`: View cukup memantau loading dan error.
abstract class ActionViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  bool get isBusy => state.isLoading;

  /// Menunggu data provider async siap. Provider dipantau selama menunggu,
  /// karena Riverpod 3 menjeda provider yang tidak punya pendengar.
  Future<T> readReady<T>(ProviderListenable<Future<T>> provider) async {
    final sub = ref.listen<Future<T>>(provider, (_, _) {});
    try {
      return await sub.read();
    } finally {
      sub.close();
    }
  }

  /// Menjalankan [action] dan mengembalikan true bila sukses.
  Future<bool> run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}
