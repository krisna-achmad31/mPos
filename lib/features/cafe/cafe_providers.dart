import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import '../auth/auth_providers.dart';
import '../auth/domain/entities/user_role.dart';
import 'data/cafe_account_repository.dart';
import 'data/cafe_repository.dart';
import 'domain/cafe.dart';

final cafeAccountRepositoryProvider = Provider(
  (ref) => CafeAccountRepository(ref.watch(firestoreProvider), ref.watch(clockProvider)),
);

/// Hanya valid saat sesi berada di POS kopi (Owner Kopi / Kasir).
final cafeRepositoryProvider = Provider(
  (ref) => CafeRepository(ref.watch(tenantStoreProvider), ref.watch(clockProvider)),
);

/// Id POS kopi milik sesi: uid Customer (juga saat masih di mode belanja) atau POS tempat Kasir bekerja.
final myCafeIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.role == UserRole.customer ? user.uid : user.cafeId;
});

final myCafeProvider = StreamProvider<Cafe?>(
  (ref) => ref.watch(cafeAccountRepositoryProvider).watchCafe(ref.watch(myCafeIdProvider)),
);

/// Premium aktif sekarang. Selama data belum termuat dianggap aktif agar layar tidak berkedip terkunci.
final cafePremiumProvider = Provider<bool>((ref) {
  final cafe = ref.watch(myCafeProvider);
  if (!cafe.hasValue) return true;
  return cafe.value?.isPremium(ref.watch(clockProvider)()) ?? false;
});

final ingredientsProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(cafeRepositoryProvider).watchIngredients(),
);

final ingredientMapProvider = Provider<Map<String, Ingredient>>(
  (ref) => {for (final i in ref.watch(ingredientsProvider).value ?? const <Ingredient>[]) i.id: i},
);

final ingredientMovementsProvider = StreamProvider.family<List<IngredientMovement>, String>(
  (ref, id) => ref.watch(cafeRepositoryProvider).watchMovements(id),
);

final recipesProvider = StreamProvider<Map<String, Recipe>>(
  (ref) => ref.watch(cafeRepositoryProvider).watchRecipes(),
);

final cafeSettingsProvider = StreamProvider<CafeSettings>(
  (ref) => ref.watch(cafeRepositoryProvider).watchSettings(),
);

// ---------------------------------------------------------------- Distributor

final premiumCodesProvider = StreamProvider<List<PremiumCode>>(
  (ref) => ref.watch(cafeAccountRepositoryProvider).watchCodes(ref.watch(distributorStoreProvider)),
);

/// POS kopi pelanggan distributor ini, dengan status premiumnya.
final distributorCafesProvider = StreamProvider<List<Cafe>>(
  (ref) => ref.watch(cafeAccountRepositoryProvider).watchCafesOf(ref.watch(currentUserProvider).distributorId),
);
