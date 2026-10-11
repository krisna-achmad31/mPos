import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/collections.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

/// Sesi tanpa login untuk mode demo: satu akun tetap per role.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._db);

  final FirebaseFirestore _db;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  static const demoUsers = {
    UserRole.owner: AppUser(uid: 'demo-owner', name: 'Owner Demo', email: 'owner@demo.local', role: UserRole.owner),
    UserRole.spv: AppUser(uid: 'demo-spv', name: 'SPV Demo', email: 'spv@demo.local', role: UserRole.spv),
    UserRole.customer: AppUser(
      uid: 'demo-customer',
      name: 'Budi',
      email: 'customer@demo.local',
      role: UserRole.customer,
      storeName: 'Toko Demo',
      phone: '081234567890',
      address: 'Jl. Contoh No. 1',
    ),
  };

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Masuk sebagai role terpilih. Profilnya disimpan di Firestore agar muncul
  /// di daftar pelanggan / pengguna milik Owner.
  Future<void> selectRole(UserRole role) async {
    final user = demoUsers[role]!;
    _current = user;
    _controller.add(user);
    try {
      await _db.collection(Collections.users).doc(user.uid).set(AppUserModel.toMap(user), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AppException('Masuk sebagai ${role.label}, tapi data tidak bisa disimpan: ${e.message}');
    }
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw const AppException('Login dimatikan di mode demo.');

  @override
  Future<void> registerCustomer({
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) =>
      throw const AppException('Pendaftaran dimatikan di mode demo.');

  @override
  Future<void> sendPasswordReset(String email) => throw const AppException('Tidak tersedia di mode demo.');
}
