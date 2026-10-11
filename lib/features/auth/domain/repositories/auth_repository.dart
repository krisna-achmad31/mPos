import '../entities/app_user.dart';
import '../entities/user_role.dart';

abstract interface class AuthRepository {
  /// null saat belum login atau profil Firestore belum ada.
  Stream<AppUser?> watchCurrentUser();

  Future<void> signIn({required String email, required String password});

  /// Distributor baru mendaftar: membuat ruang distributor dan menjadi Owner di sana.
  Future<void> registerDistributor({
    required String ownerName,
    required String distributorName,
    required String phone,
    required String email,
    required String password,
  });

  /// Pendaftaran pelanggan ke satu distributor.
  Future<void> registerCustomer({
    required String distributorId,
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
  /// Akun milik satu distributor saja.
  Stream<List<AppUser>> watchUsers({required String distributorId, UserRole? role});

  Future<void> updateRole(String uid, UserRole role);

  Future<void> setActive(String uid, bool active);
}
