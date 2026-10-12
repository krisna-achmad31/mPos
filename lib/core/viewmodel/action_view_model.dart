import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../error/app_exception.dart';

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
    var result = await AsyncValue.guard(action);
    if (result case AsyncError(:final error, :final stackTrace)) {
      final message = cleanErrorMessage(error);
      if (message != null) result = AsyncError(AppException(message), stackTrace);
    }
    if (!ref.mounted) return !result.hasError;
    state = result;
    return !result.hasError;
  }
}

/// Di web, AppException yang dilempar di dalam transaksi Firestore sampai sebagai
/// `Error: Dart exception: pesan`. Mengembalikan pesan aslinya, atau null bila bukan kasus itu.
String? cleanErrorMessage(Object error) {
  const marker = 'Dart exception: ';
  final text = '$error';
  final i = text.indexOf(marker);
  return i < 0 ? null : text.substring(i + marker.length).trim();
}
