import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
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
  Future<bool> save(StoreSettings settings) => run(() => ref.read(settingsRepositoryProvider).save(settings));

  Future<bool> saveLogo(Uint8List png) => run(() async {
        validateLogoPng(png);
        await ref.read(settingsRepositoryProvider).saveLogo(png);
      });

  Future<bool> removeLogo() => run(() => ref.read(settingsRepositoryProvider).saveLogo(null));
}

final settingsViewModelProvider = NotifierProvider<SettingsViewModel, AsyncValue<void>>(SettingsViewModel.new);
