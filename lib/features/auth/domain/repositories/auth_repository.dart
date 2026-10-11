import '../entities/app_user.dart';
import '../entities/user_role.dart';

abstract interface class AuthRepository {
  /// null saat belum login atau profil Firestore belum ada.
  Stream<AppUser?> watchCurrentUser();

  Future<void> signIn({required String email, required String password});

  /// Pendaftaran mandiri, selalu sebagai Customer.
  Future<void> registerCustomer({
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}

abstract interface class UserRepository {
  Stream<List<AppUser>> watchUsers({UserRole? role});

  Future<void> updateRole(String uid, UserRole role);

  Future<void> setActive(String uid, bool active);
}
