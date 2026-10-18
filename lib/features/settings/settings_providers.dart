import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../../core/error/app_exception.dart';
import '../../core/utils/png_logo.dart';
import '../../core/viewmodel/action_view_model.dart';
import 'data/firestore_settings_repository.dart';
import 'domain/store_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(ref.watch(tenantStoreProvider)),
);

final storeSettingsProvider = StreamProvider<StoreSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Logo PNG distributor; null = invoice hanya menampilkan nama.
final distributorLogoProvider = StreamProvider<Uint8List?>(
  (ref) => ref.watch(settingsRepositoryProvider).watchLogo(),
);

class SettingsViewModel extends ActionViewModel {
  /// Nama toko = nama distributor: ikut diperbarui agar kop invoice, sidebar, dan pilihan distributor sama.
  Future<bool> save(StoreSettings settings) => run(() async {
        if (settings.marginPercent < 0) throw const AppException('Margin tidak boleh negatif.');
        await ref.read(settingsRepositoryProvider).save(settings);
        final name = settings.storeName.trim();
        final distributor = await readReady(currentDistributorProvider.future);
        if (name.isNotEmpty && distributor != null && distributor.name != name) {
          await ref.read(distributorRepositoryProvider).rename(distributor.id, name);
        }
      });

  Future<bool> saveLogo(Uint8List png) => run(() async {
        validateLogoPng(png);
        await ref.read(settingsRepositoryProvider).saveLogo(png);
      });

  Future<bool> removeLogo() => run(() => ref.read(settingsRepositoryProvider).saveLogo(null));
}

final settingsViewModelProvider = NotifierProvider<SettingsViewModel, AsyncValue<void>>(SettingsViewModel.new);
