import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/firebase/firebase_providers.dart';
import '../../core/firebase/tenant_store.dart';
import '../distributors/data/firestore_distributor_repository.dart';
import '../distributors/domain/distributor.dart';
import 'data/repositories/demo_auth_repository.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'domain/entities/app_user.dart';
import 'domain/entities/user_role.dart';
import 'domain/repositories/auth_repository.dart';

final demoAuthRepositoryProvider = Provider<DemoAuthRepository>(
  (ref) => DemoAuthRepository(ref.watch(firestoreProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.demoMode
      ? ref.watch(demoAuthRepositoryProvider)
      : FirebaseAuthRepository(ref.watch(firebaseAuthProvider), ref.watch(firestoreProvider)),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => FirestoreUserRepository(ref.watch(firestoreProvider)),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchCurrentUser(),
);

/// Customer sedang membuka POS kopinya (true) atau berbelanja ke distributor (false).
class CafeModeViewModel extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool on) => state = on;
}

final cafeModeProvider = NotifierProvider<CafeModeViewModel, bool>(CafeModeViewModel.new);

/// Sesi efektif: akun login, atau akun Customer yang sedang menjadi Owner Kopi.
/// Router dan semua layar memakai ini, sehingga pindah mode berlaku sebelum layar dibangun.
final sessionProvider = Provider<AsyncValue<AppUser?>>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.value;
  if (user != null && user.role == UserRole.customer && ref.watch(cafeModeProvider)) {
    return AsyncData(user.asCafeOwner());
  }
  return auth;
});

/// Pengguna yang sedang login. Hanya dipakai di layar yang sudah dijaga router.
final currentUserProvider = Provider<AppUser>((ref) {
  final user = ref.watch(sessionProvider).value;
  if (user == null) throw StateError('Belum login');
  return user;
});

/// Semua data bisnis dibaca dari tenant akun yang login: distributornya, atau POS kopinya.
final tenantStoreProvider = Provider<TenantStore>((ref) {
  final user = ref.watch(currentUserProvider);
  final db = ref.watch(firestoreProvider);
  return user.role.isCafe ? TenantStore.cafe(db, user.cafeId) : TenantStore(db, user.distributorId);
});

/// Data distributor milik akun, juga saat sedang di POS kopi (aktivasi premium, stok dari distributor).
final distributorStoreProvider = Provider<TenantStore>(
  (ref) => TenantStore(ref.watch(firestoreProvider), ref.watch(currentUserProvider).distributorId),
);

/// true saat layar sedang bekerja di data POS kopi.
final isCafeWorkspaceProvider = Provider<bool>((ref) => ref.watch(currentUserProvider).role.isCafe);

final distributorRepositoryProvider = Provider<DistributorRepository>(
  (ref) => FirestoreDistributorRepository(ref.watch(firestoreProvider)),
);

final distributorsProvider = StreamProvider<List<Distributor>>(
  (ref) => ref.watch(distributorRepositoryProvider).watchAll(),
);

final currentDistributorProvider = StreamProvider<Distributor?>(
  (ref) => ref.watch(distributorRepositoryProvider).watch(ref.watch(currentUserProvider).distributorId),
);

/// Pelanggan milik distributor ini saja.
final customersProvider = StreamProvider<List<AppUser>>((ref) => ref
    .watch(userRepositoryProvider)
    .watchUsers(distributorId: ref.watch(currentUserProvider).distributorId, role: UserRole.customer));

final allUsersProvider = StreamProvider<List<AppUser>>((ref) =>
    ref.watch(userRepositoryProvider).watchUsers(distributorId: ref.watch(currentUserProvider).distributorId));
