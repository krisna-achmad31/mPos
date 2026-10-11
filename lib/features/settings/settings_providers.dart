import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../../core/viewmodel/action_view_model.dart';
import 'data/firestore_settings_repository.dart';
import 'domain/store_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FirestoreSettingsRepository(ref.watch(firestoreProvider)),
);

final storeSettingsProvider = StreamProvider<StoreSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

class SettingsViewModel extends ActionViewModel {
  Future<bool> save(StoreSettings settings) => run(() => ref.read(settingsRepositoryProvider).save(settings));
}

final settingsViewModelProvider = NotifierProvider<SettingsViewModel, AsyncValue<void>>(SettingsViewModel.new);
