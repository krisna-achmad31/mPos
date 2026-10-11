import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/firebase/firebase_providers.dart';
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

/// Pengguna yang sedang login. Hanya dipakai di layar yang sudah dijaga router.
final currentUserProvider = Provider<AppUser>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) throw StateError('Belum login');
  return user;
});

final customersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(userRepositoryProvider).watchUsers(role: UserRole.customer),
);

final allUsersProvider = StreamProvider<List<AppUser>>(
  (ref) => ref.watch(userRepositoryProvider).watchUsers(),
);
