import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/collections.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';
import '../../../distributors/data/firestore_distributor_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _db.collection(Collections.users).doc(user.uid).snapshots().map(
            (snap) => snap.exists ? AppUserModel.fromMap(snap.id, snap.data()!) : null,
          );
    });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  @override
  Future<void> registerDistributor({
    required String ownerName,
    required String distributorName,
    required String phone,
    required String email,
    required String password,
  }) async {
    if (distributorName.trim().isEmpty) throw const AppException('Nama distributor wajib diisi.');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final uid = credential.user!.uid;
      final distributorRef = _db.collection(Collections.distributors).doc();
      final user = AppUser(
        uid: uid,
        name: ownerName.trim(),
        email: email.trim(),
        role: UserRole.owner,
        distributorId: distributorRef.id,
        phone: phone.trim(),
      );
      // Satu batch: distributor + profil Owner dibuat bersamaan (rules memeriksa keduanya).
      await (_db.batch()
            ..set(distributorRef,
                FirestoreDistributorRepository.newDistributorMap(name: distributorName, ownerUid: uid, phone: phone))
            ..set(distributorRef.collection(Collections.settings).doc('store'),
                FirestoreDistributorRepository.initialSettingsMap(distributorName))
            ..set(_db.collection(Collections.users).doc(uid), {
              ...AppUserModel.toMap(user),
              'createdAt': FieldValue.serverTimestamp(),
            }))
          .commit();
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  @override
  Future<void> registerCustomer({
    required String distributorId,
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) async {
    if (distributorId.isEmpty) throw const AppException('Pilih distributor terlebih dahulu.');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = AppUser(
        uid: credential.user!.uid,
        name: name.trim(),
        email: email.trim(),
        role: UserRole.customer,
        distributorId: distributorId,
        storeName: storeName.trim(),
        phone: phone.trim(),
        address: address.trim(),
      );
      await _db.collection(Collections.users).doc(user.uid).set({
        ...AppUserModel.toMap(user),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  String _message(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'Format email tidak valid.',
        'user-disabled' => 'Akun ini dinonaktifkan.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email atau password salah.',
        'email-already-in-use' => 'Email sudah terdaftar.',
        'weak-password' => 'Password minimal 6 karakter.',
        'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
        'network-request-failed' => 'Tidak ada koneksi internet.',
        _ => e.message ?? 'Terjadi kesalahan autentikasi.',
      };
}

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection(Collections.users);

  @override
  Stream<List<AppUser>> watchUsers({required String distributorId, UserRole? role}) {
    Query<Map<String, dynamic>> query = _users.where('distributorId', isEqualTo: distributorId);
    if (role != null) query = query.where('role', isEqualTo: role.name);
    return query.snapshots().map((snap) {
      final users = snap.docs.map((d) => AppUserModel.fromMap(d.id, d.data())).toList();
      users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return users;
    });
  }

  @override
  Future<void> updateRole(String uid, UserRole role) => _users.doc(uid).update({'role': role.name});

  @override
  Future<void> setActive(String uid, bool active) => _users.doc(uid).update({'active': active});
}
