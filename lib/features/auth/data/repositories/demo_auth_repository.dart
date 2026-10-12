import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/firebase/collections.dart';
import '../../../distributors/data/firestore_distributor_repository.dart';
import '../../../distributors/domain/distributor.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/app_user_model.dart';

/// Sesi tanpa login untuk pilot: pilih distributor, lalu pilih role.
/// Setiap distributor punya satu akun demo tetap per role.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._db);

  final FirebaseFirestore _db;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  static String demoUid(String distributorId, UserRole role, {int customer = 1}) => switch (role) {
        UserRole.customer || UserRole.cafeOwner => 'demo-$distributorId-customer-$customer',
        UserRole.cashier => 'demo-$distributorId-cashier-$customer',
        _ => 'demo-$distributorId-${role.name}',
      };

  /// Kasir uji di POS kopi milik pelanggan uji nomor [number].
  static AppUser demoCashier(Distributor d, int number) => AppUser(
        uid: demoUid(d.id, UserRole.cashier, customer: number),
        name: const ['Sari', 'Bayu'][number - 1],
        email: 'kasir$number@demo.local',
        role: UserRole.cashier,
        distributorId: d.id,
        storeName: demoCustomers[number - 1].store,
        cafeId: demoUid(d.id, UserRole.customer, customer: number),
      );

  /// Dua pelanggan uji agar harga khusus / promo per akun bisa dibandingkan.
  static const demoCustomers = [
    (name: 'Rina', store: 'Kopi Senja Sore', phone: '081200000001', address: 'Jl. Melati No. 5'),
    (name: 'Dimas', store: 'Ruang Temu Coffee', phone: '081200000002', address: 'Jl. Kenanga No. 12'),
  ];

  static AppUser demoCustomer(Distributor d, int number) {
    final c = demoCustomers[number - 1];
    return AppUser(
      uid: demoUid(d.id, UserRole.customer, customer: number),
      name: c.name,
      email: 'customer$number@demo.local',
      role: UserRole.customer,
      distributorId: d.id,
      storeName: c.store,
      phone: c.phone,
      address: c.address,
    );
  }

  static AppUser demoUser(Distributor d, UserRole role, {int customer = 1}) => switch (role) {
        UserRole.owner => AppUser(
            uid: demoUid(d.id, role),
            name: 'Owner ${d.name}',
            email: 'owner@demo.local',
            role: role,
            distributorId: d.id,
          ),
        UserRole.spv => AppUser(
            uid: demoUid(d.id, role),
            name: 'SPV ${d.name}',
            email: 'spv@demo.local',
            role: role,
            distributorId: d.id,
          ),
        UserRole.customer => demoCustomer(d, customer),
        UserRole.cafeOwner => demoCustomer(d, customer).asCafeOwner(),
        UserRole.cashier => demoCashier(d, customer),
      };

  @override
  Stream<AppUser?> watchCurrentUser() async* {
    yield _current;
    yield* _controller.stream;
  }

  /// Membuat distributor baru untuk pilot. Mengembalikan distributor itu.
  Future<Distributor> createDistributor(String name) async {
    if (name.trim().isEmpty) throw const AppException('Nama distributor wajib diisi.');
    final ref = _db.collection(Collections.distributors).doc();
    final ownerUid = demoUid(ref.id, UserRole.owner);
    await (_db.batch()
          ..set(ref, FirestoreDistributorRepository.newDistributorMap(name: name, ownerUid: ownerUid))
          ..set(ref.collection(Collections.settings).doc('store'), FirestoreDistributorRepository.initialSettingsMap(name)))
        .commit();
    return Distributor(id: ref.id, name: name.trim(), ownerUid: ownerUid);
  }

  /// Masuk sebagai [role] di [distributor] ([customer] = akun pelanggan uji 1 atau 2).
  /// Kedua pelanggan uji selalu disimpan agar langsung bisa dipilih Owner di harga khusus / promo.
  Future<void> selectRole(Distributor distributor, UserRole role, {int customer = 1}) async {
    final user = demoUser(distributor, role, customer: customer);
    _current = user;
    _controller.add(user);
    try {
      final users = _db.collection(Collections.users);
      final batch = _db.batch()..set(users.doc(user.uid), AppUserModel.toMap(user), SetOptions(merge: true));
      // SPV (kurir) dan dua pelanggan uji selalu ada agar bisa langsung dipilih Owner.
      final spv = demoUser(distributor, UserRole.spv);
      batch.set(users.doc(spv.uid), AppUserModel.toMap(spv), SetOptions(merge: true));
      for (var i = 1; i <= demoCustomers.length; i++) {
        final c = demoCustomer(distributor, i);
        batch.set(users.doc(c.uid), AppUserModel.toMap(c), SetOptions(merge: true));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Masuk sebagai ${role.label}, tapi profil tidak bisa disimpan: ${e.message}');
    }
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw const AppException('Login dimatikan di mode pilot.');

  @override
  Future<void> registerDistributor({
    required String ownerName,
    required String distributorName,
    required String phone,
    required String email,
    required String password,
  }) =>
      throw const AppException('Pendaftaran dimatikan di mode pilot.');

  @override
  Future<void> registerCustomer({
    required String distributorId,
    required String name,
    required String storeName,
    required String phone,
    required String address,
    required String email,
    required String password,
  }) =>
      throw const AppException('Pendaftaran dimatikan di mode pilot.');

  @override
  Future<void> sendPasswordReset(String email) => throw const AppException('Tidak tersedia di mode pilot.');
}
